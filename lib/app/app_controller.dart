import '../features/catalog/data/account_catalog_repository.dart';
import '../features/playlists/domain/music_playlist.dart';
import '../features/catalog/data/local_catalog_repository.dart';
import '../features/profile/domain/access_repository.dart';
import '../features/activity/data/listening_tracker.dart';
import '../features/activity/domain/listening_repository.dart';
import '../features/activity/domain/likes_repository.dart';
import '../features/player/data/music_audio_handler.dart';
import 'dart:async';
import '../features/admin/domain/admin_access_repository.dart';
import '../features/admin/presentation/admin_access_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import '../features/profile/domain/profile_repository.dart';
import 'package:flutter/material.dart';
import '../core/storage/preferences_service.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/catalog/domain/song.dart';
import '../features/auth/data/firebase_auth_repository.dart';

class AppController extends ChangeNotifier {
  AppController(this._preferences, this.catalog, {this.auth, this.profiles, this.access, this.audio, this.likes, this.history, this.listening, AdminAccessRepository? adminRepository})
      : adminAccess = AdminAccessController(adminRepository) {
    adminAccess.addListener(notifyListeners);
    final Object source = catalog;
    if (source is ChangeNotifier) source.addListener(notifyListeners);
    themeMode = switch (_preferences.theme) {
      'light' => ThemeMode.light, 'system' => ThemeMode.system, _ => ThemeMode.dark,
    };
    name = _preferences.name;
    _favorites = _preferences.favorites;
    sessionReady = auth == null;
    _subscription = auth?.sessionChanges.listen((user) {
      final changed = userId != user?.uid;
      userId = user?.uid;
      email = user?.email;
      name = user == null ? _preferences.name :
          (user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'Usuario');
      _favorites = _preferences.favoritesFor(owner);
      if (changed) { _bindCatalog(userId); _accessPendingUid = userId; listening?.bind(userId); unawaited(audio?.stop()); demoOpen = false; adminAccess.bind(userId); }
      sessionReady = true;
      sessionError = false;
      unawaited(syncProfile());
      notifyListeners();
    }, onError: (Object error) {
      _accessPendingUid = null;
      _bindCatalog(null);
      listening?.bind(null);
      unawaited(audio?.stop());
      _profileRevision++; profileSyncing = false; profileError = null;
      userId = null; email = null; demoOpen = false;
      adminAccess.bind(null);
      name = _preferences.name; _favorites = _preferences.favorites;
      sessionReady = true; sessionError = true; notifyListeners();
    });
  }
  Future<void> _playlistQueue = Future<void>.value();
  List<MusicPlaylist> get playlists =>
      userId == null ? [] : _preferences.playlistsFor(userId!);
  Future<void> savePlaylist({
    required String uid,
    String? id,
    required String title,
    required List<String> songs,
  }) {
    final operation = _playlistQueue.then((_) async {
      if (_disposed || userId != uid) {
        throw StateError('La sesión cambió. Abre la biblioteca de tu cuenta.');
      }
      final name = title.trim();
      if (name.isEmpty || name.length > 60) {
        throw ArgumentError('Usa un nombre de 1 a 60 caracteres.');
      }
      final current = _preferences.playlistsFor(uid);
      final playlist = MusicPlaylist(
        id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        songIds: songs.toSet().toList(),
      );
      final index = current.indexWhere((p) => p.id == playlist.id);
      if (index < 0) {
        current.add(playlist);
      } else {
        current[index] = playlist;
      }
      await _preferences.savePlaylists(uid, current);
      if (!_disposed && userId == uid) {
        notifyListeners();
      }
    });
    _playlistQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> deletePlaylist(String uid, String id) {
    final operation = _playlistQueue.then((_) async {
      if (_disposed || userId != uid) {
        throw StateError('La sesión cambió.');
      }
      final current = _preferences.playlistsFor(uid)
        ..removeWhere((p) => p.id == id);
      await _preferences.savePlaylists(uid, current);
      if (!_disposed && userId == uid) {
        notifyListeners();
      }
    });
    _playlistQueue = operation.catchError((Object _) {});
    return operation;
  }

  final MusicAudioHandler? audio;
  final LikesRepository? likes;
  final ListeningRepository? history;
  final ListeningTracker? listening;
  final Set<String> _favoriteWrites = {};
  bool favoriteSaving(Song song) => _favoriteWrites.contains('$owner/${song.id}');
  final AdminAccessController adminAccess;
  bool get isAdmin => isSignedIn && adminAccess.allowed;
  final PreferencesService _preferences;
  final CatalogRepository catalog;
  LocalCatalogRepository? get localCatalog {
    final source = catalog;
    if (source is AccountCatalogRepository) {
      return source.owner == userId ? source.local : null;
    }
    return source is LocalCatalogRepository ? source : null;
  }
  bool get canManageMusic => isSignedIn && localCatalog != null;
  void _bindCatalog(String? uid) {
    final source = catalog;
    if (source is AccountCatalogRepository) unawaited(source.bind(uid));
  }
  void retryLibrary() => _bindCatalog(userId);
  final FirebaseAuthRepository? auth;
  final ProfileRepository? profiles;
  final AccessRepository? access;
  String? _accessPendingUid;
  Future<void> _profileQueue = Future<void>.value();
  int _profileRevision = 0;
  bool _disposed = false;
  bool profileSyncing = false;
  String? profileError;

  Future<void> syncProfile() {
    final revision = ++_profileRevision;
    final uid = userId;
    final repository = profiles;
    final profileName = name;
    final profileEmail = email;
    profileError = null;
    profileSyncing = uid != null && repository != null;
    if (!_disposed) notifyListeners();
    if (uid == null || repository == null) return Future<void>.value();
    // Serialize writes so registration's name update cannot be overwritten
    // by an earlier event. Ignore results belonging to an old account.
    _profileQueue = _profileQueue.then((_) async {
      if (_disposed || revision != _profileRevision || userId != uid) return;
      try {
        if (profileEmail == null || profileEmail.isEmpty) {
          throw StateError('La cuenta no tiene correo.');
        }
        await repository.sync(uid: uid, name: profileName, email: profileEmail);
        // Solo al entrar con una cuenta o restaurar la sesión al arrancar.
        // Cambiar el nombre o renovar el token no es un nuevo acceso.
        if (!_disposed && revision == _profileRevision && userId == uid
            && _accessPendingUid == uid && access != null) {
          await access!.record(uid);
          if (!_disposed && revision == _profileRevision && userId == uid) {
            _accessPendingUid = null;
          }
        }
      } catch (error) {
        if (!_disposed && revision == _profileRevision && userId == uid) {
          profileError = error is FirebaseException && error.code == 'permission-denied'
              ? 'No se pudo sincronizar tu perfil o último acceso. Revisa las reglas publicadas en Firestore.'
              : 'No se pudo sincronizar tu perfil o último acceso. Comprueba tu conexión y reintenta.';
        }
      } finally {
        if (!_disposed && revision == _profileRevision && userId == uid) {
          profileSyncing = false;
          notifyListeners();
        }
      }
    });
    return _profileQueue;
  }

  StreamSubscription<dynamic>? _subscription;
  late ThemeMode themeMode;
  late String name;
  late Set<String> _favorites;
  late bool sessionReady;
  bool sessionError = false, demoOpen = false;
  String? userId, email;
  bool get isSignedIn => userId != null;
  String get owner => userId ?? 'demo';
  bool isFavorite(Song song) => _favorites.contains(song.id);
  void enterDemo() { listening?.bind(null); demoOpen = true; notifyListeners(); }
  void leaveDemo() { unawaited(audio?.stop()); demoOpen = false; notifyListeners(); }
  Future<void> signOut() async {
    listening?.bind(null);
    await audio?.stop();
    try {
      if (auth != null) {
        await auth!.signOut();
      }
    } catch (_) {
      listening?.bind(userId);
      rethrow;
    }
  }
  Future<void> setTheme(ThemeMode mode) async {
    await _preferences.saveTheme(mode.name); themeMode = mode; notifyListeners();
  }
  Future<void> setName(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    if (cleaned.length > 100) throw ArgumentError('El nombre admite hasta 100 caracteres.');
    if (isSignedIn) {
      await auth!.updateName(cleaned);
      // userChanges actualiza el nombre y avisa a las pantallas.
    } else {
      await _preferences.saveName(cleaned); name = cleaned; notifyListeners();
    }
  }
  Future<void> toggleFavorite(Song song) async {
    final account = owner;
    final uid = userId;
    final writeKey = '$account/${song.id}';
    // Una escritura por canción/cuenta: evita dobles toques mientras se confirma.
    if (!_favoriteWrites.add(writeKey)) {
      return;
    }
    final wasLiked = _favorites.contains(song.id);
    final next = {..._favorites};
    if (wasLiked) {
      next.remove(song.id);
    } else {
      next.add(song.id);
    }
    _favorites = next;
    notifyListeners();
    var cloudSaved = false;
    try {
      if (uid != null && likes != null) {
        await likes!.setLike(uid, song, !wasLiked);
        cloudSaved = true;
      }
      // Persiste solo esta canción en su cuenta original, incluso si cambió
      // la sesión. No guarda otros cambios todavía pendientes de confirmación.
      final saved = _preferences.favoritesFor(account);
      if (wasLiked) {
        saved.remove(song.id);
      } else {
        saved.add(song.id);
      }
      await _preferences.saveFavoritesFor(account, saved);
      if (!_disposed && owner == account) {
        final current = {..._favorites};
        if (wasLiked) {
          current.remove(song.id);
        } else {
          current.add(song.id);
        }
        _favorites = current;
      }
    } catch (_) {
      if (!_disposed && owner == account && !cloudSaved) {
        // Revierte solo esta canción, sin perder otros likes concurrentes.
        final reverted = {..._favorites};
        if (wasLiked) {
          reverted.add(song.id);
        } else {
          reverted.remove(song.id);
        }
        _favorites = reverted;
      }
      rethrow;
    } finally {
      _favoriteWrites.remove(writeKey);
      if (!_disposed) {
        notifyListeners();
      }
    }
  }
  @override
  void dispose() { listening?.dispose(); _disposed = true; _profileRevision++; _subscription?.cancel(); final Object source = catalog; if (source is ChangeNotifier) source.removeListener(notifyListeners); adminAccess.removeListener(notifyListeners); adminAccess.dispose(); super.dispose(); }
}
