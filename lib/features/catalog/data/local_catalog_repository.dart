import '../../../core/validation/form_validators.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/catalog_repository.dart';
import '../domain/song.dart';
import '../domain/music_moods.dart';

class LocalCatalogRepository extends ChangeNotifier implements CatalogRepository {
  LocalCatalogRepository._(this.directory);
  final Directory directory;
  List<Song> _songs = [];
  bool _busy = false;
  @override
  List<Song> get songs => List.unmodifiable(_songs);
  static Future<LocalCatalogRepository> open({Directory? directory}) async {
    final base = directory ?? Directory('${(await getApplicationDocumentsDirectory()).path}/mood_music_library');
    await base.create(recursive: true);
    final repo = LocalCatalogRepository._(base);
    final index = File('${base.path}/catalog.json');
    if (await index.exists()) {
      final rows = jsonDecode(await index.readAsString()) as List;
      repo._songs = rows.map((row) {
        final data = Map<String, dynamic>.from(row as Map);
        String? resolve(String key) {
          final value = data[key] as String?;
          if (value == null) return null;
          if (value == '.' || value == '..' || !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(value)) throw const FormatException('Archivo inválido');
          return '${base.path}/$value';
        }
        return Song(id: data['id'] as String, title: data['title'] as String,
          artist: data['artist'] as String, genre: data['genre'] as String,
          moods: readMoods(data['moods']), audioUrl: resolve('audio'), coverUrl: resolve('cover'));
      }).toList();
    }
    return repo;
  }
  String _basename(String path) => path.replaceAll('\\', '/').split('/').last;
  Future<void> _commit(List<Song> next) async {
    final temp = File('${directory.path}/catalog.pending');
    await temp.writeAsString(jsonEncode(next.map((s) => {
      'id': s.id, 'title': s.title, 'artist': s.artist, 'genre': s.genre,
      'moods': s.moods,
      'audio': s.audioUrl == null ? null : _basename(s.audioUrl!),
      'cover': s.coverUrl == null ? null : _basename(s.coverUrl!),
    }).toList()), flush: true);
    await temp.rename('${directory.path}/catalog.json');
    _songs = next;
    notifyListeners();
  }
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) throw StateError('Espera a que termine la operación anterior.');
    _busy = true;
    try { return await action(); } finally { _busy = false; }
  }
  Future<Song> save({Song? existing, required String title, required String artist,
      required String genre, List<String>? moods, File? audio, File? cover}) => _exclusive(() async {
    final validation = validateSongTitle(title) ?? validateArtist(artist);
    if (validation != null) throw ArgumentError(validation);
    if ([title, artist, genre].any((v) => v.trim().isEmpty || v.trim().length > 100)) {
      throw ArgumentError('Completa los campos con un máximo de 100 caracteres.');
    }
    if (existing != null && !_songs.any((s) => s.id == existing.id)) throw StateError('La canción ya no existe.');
    if (existing == null && audio == null) throw ArgumentError('Selecciona un audio.');
    final token = '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
    final created = <File>[];
    Future<String> copy(File source, String kind, int max, Set<String> extensions) async {
      final size = await source.length();
      final ext = source.path.split('.').last.toLowerCase();
      if (size == 0 || size > max || !extensions.contains(ext)) throw ArgumentError('Archivo vacío, demasiado grande o formato no admitido.');
      final dest = File('${directory.path}/${token}_$kind.$ext');
      created.add(dest);
      await source.copy(dest.path);
      return dest.path;
    }
    late Song song;
    try {
      song = Song(id: existing?.id ?? token, title: title.trim(), artist: artist.trim(), genre: genre.trim(),
        moods: readMoods(moods ?? existing?.moods),
        audioUrl: audio == null ? existing?.audioUrl : await copy(audio, 'audio', 100 * 1024 * 1024, {'mp3','m4a','aac','wav','ogg','flac'}),
        coverUrl: cover == null ? existing?.coverUrl : await copy(cover, 'cover', 5 * 1024 * 1024, {'jpg','jpeg','png','webp'}));
      await _commit(existing == null ? [..._songs, song] : _songs.map((s) => s.id == existing.id ? song : s).toList());
    } catch (_) {
      for (final file in created) { await _cleanup(file.path); }
      rethrow;
    }
    if (existing?.audioUrl != song.audioUrl) await _cleanup(existing?.audioUrl);
    if (existing?.coverUrl != song.coverUrl) await _cleanup(existing?.coverUrl);
    return song;
  });
  Future<void> remove(Song song) => _exclusive(() async {
    final matches = _songs.where((s) => s.id == song.id);
    if (matches.isEmpty) throw StateError('La canción no pertenece a esta biblioteca.');
    final stored = matches.single;
    await _commit(_songs.where((s) => s.id != stored.id).toList());
    await _cleanup(stored.audioUrl);
    await _cleanup(stored.coverUrl);
  });
  Future<void> _cleanup(String? path) async {
    if (path == null || File(path).parent.absolute.uri.normalizePath() != directory.absolute.uri.normalizePath()) return;
    try { final file = File(path); if (await file.exists()) await file.delete(); }
    on FileSystemException { debugPrint('No se pudo limpiar un archivo local de MoodMusic.'); }
  }
}
