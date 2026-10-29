import 'dart:io';
import 'dart:async';
import '../domain/media_uri.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../catalog/domain/song.dart';
import '../domain/playback_queue.dart';
import 'remote_audio_cache.dart';

/// Un solo reproductor por aplicación. Las pantallas no lo destruyen.
class MusicAudioHandler extends BaseAudioHandler {
  MusicAudioHandler({
    AudioPlayer? audioPlayer,
    Future<File> Function(Uri uri)? resolveRemoteAudio,
  })  : player = audioPlayer ?? AudioPlayer(),
        _resolveRemoteAudio = resolveRemoteAudio ?? RemoteAudioCache().resolve {
    player.playbackEventStream
        .listen((_) => _publish(), onError: (Object e) => _fail(e));
    player.playerStateStream.listen((_) => _publish());
    player.currentIndexStream.listen((_) {
      _publishItem();
      _publish();
    });
    player.durationStream.listen((_) => _publishItem());
    player.errorStream.listen(_fail);
  }
  final AudioPlayer player;
  final Future<File> Function(Uri uri) _resolveRemoteAudio;
  final ValueNotifier<int> changes = ValueNotifier(0);
  List<Song> _songs = const [];
  Future<void> _operations = Future<void>.value();
  int _generation = 0;
  bool _active = false;
  bool loading = false;
  bool welcomeOnNextOpen = false;
  String? error;
  List<Song> get songs => _songs;
  int get index => player.currentIndex ?? 0;
  Song? get currentSong => !_active || _songs.isEmpty
      ? null
      : _songs[index.clamp(0, _songs.length - 1).toInt()];
  bool get hasPrevious => _active && index > 0;
  bool get hasNext => _active && index + 1 < _songs.length;
  bool get isPlaying =>
      player.playing && player.processingState != ProcessingState.completed;
  void _changed() => changes.value++;
  MediaItem _item(Song s, {Duration? duration}) => MediaItem(
        id: s.id,
        title: s.title,
        artist: s.artist,
        genre: s.genre,
        artUri: s.coverUrl == null ? null : mediaUri(s.coverUrl!),
        duration: duration,
      );
  Future<AudioSource> _audioSource(Song song,
      {required bool cacheRemote}) async {
    if (song.id == 'shared_demo_01') {
      return AudioSource.asset('hosting_audio/audio/viva-la-vida.mp3');
    }
    final uri = mediaUri(song.audioUrl!);
    if (cacheRemote && uri.scheme == 'https') {
      return AudioSource.uri((await _resolveRemoteAudio(uri)).uri);
    }
    return AudioSource.uri(uri);
  }

  void _publishItem() {
    final s = currentSong;
    mediaItem.add(s == null ? null : _item(s, duration: player.duration));
    _changed();
  }

  void _publish() {
    playbackState.add(PlaybackState(
      controls: [
        if (hasPrevious) MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        if (hasNext) MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      processingState: !_active
          ? AudioProcessingState.idle
          : error != null
              ? AudioProcessingState.error
              : loading
                  ? AudioProcessingState.loading
                  : switch (player.processingState) {
                      ProcessingState.idle => AudioProcessingState.idle,
                      ProcessingState.loading => AudioProcessingState.loading,
                      ProcessingState.buffering =>
                        AudioProcessingState.buffering,
                      ProcessingState.ready => AudioProcessingState.ready,
                      ProcessingState.completed =>
                        AudioProcessingState.completed,
                    },
      playing: _active && isPlaying && error == null,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: _active ? index : null,
      errorCode: error == null ? null : 1,
      errorMessage: error,
    ));
    _changed();
  }

  void _fail(Object e, {bool force = false}) {
    if ((!_active && !force) || e is PlayerInterruptedException) return;
    debugPrint(
        'MoodMusic audio: song=${currentSong?.id}, state=${player.processingState}, error=$e');
    error = e is TimeoutException
        ? 'El audio tardó demasiado en responder. Comprueba tu conexión y pulsa Reintentar.'
        : 'No se pudo reproducir el audio. Comprueba tu conexión o el archivo y pulsa Reintentar.';
    loading = false;
    unawaited(player.pause().catchError((Object _) {}));
    _publish();
  }

  Future<void> _enqueue(Future<void> Function(int generation) action,
      {Duration timeout = const Duration(seconds: 25)}) {
    final generation = _generation;
    final next = _operations.then((_) async {
      if (generation != _generation) return;
      try {
        await action(generation).timeout(timeout);
      } on TimeoutException catch (e) {
        if (generation == _generation) {
          // Invalidate queued/stale commands before releasing a stuck native load.
          ++_generation;
          _fail(e, force: true);
          try {
            await player.stop().timeout(const Duration(seconds: 3));
          } catch (_) {}
        }
      } catch (e) {
        if (generation == _generation) _fail(e, force: true);
      }
    });
    _operations = next;
    return next;
  }

  Future<void> open(List<Song> catalog, Song selected,
      {bool force = false, Duration initialPosition = Duration.zero}) {
    if (!force &&
        currentSong?.id == selected.id &&
        error == null &&
        listEquals(_songs.map((s) => s.id).toList(),
            buildPlaybackQueue(catalog, selected).map((s) => s.id).toList())) {
      return Future<void>.value();
    }
    ++_generation; // Ignore callbacks/commands belonging to the previous load.
    return _enqueue((generation) async {
      loading = true;
      error = null;
      _publish();
      await player.stop();
      if (generation != _generation) return;
      _songs = buildPlaybackQueue(catalog, selected);
      _active = _songs.isNotEmpty;
      if (!_active) {
        loading = false;
        _publish();
        return;
      }
      error = null;
      loading = true;
      queue.add(_songs.map((s) => _item(s)).toList());
      _publish();
      final selectedIndex = _songs.indexWhere((s) => s.id == selected.id);
      final sources = <AudioSource>[];
      for (var i = 0; i < _songs.length; i++) {
        sources.add(
            await _audioSource(_songs[i], cacheRemote: i == selectedIndex));
        if (generation != _generation) return;
      }
      await player.setAudioSources(
        sources,
        initialIndex: selectedIndex < 0 ? 0 : selectedIndex,
        initialPosition: initialPosition,
      );
      if (generation != _generation) return;
      if (error != null) return;
      loading = false;
      _publishItem();
      _publish();
      _start(generation);
    }, timeout: const Duration(seconds: 90));
  }

  Future<void> retry() {
    final selected = currentSong;
    if (selected == null || loading) return Future<void>.value();
    final position = player.position;
    // Retry the CURRENT song, even after moving through a playlist.
    return open(List<Song>.of(_songs), selected,
        force: true, initialPosition: position);
  }

  void _start(int generation) {
    if (generation != _generation || !_active) return;
    // play() completes at pause/end; do not block the command queue on it.
    unawaited(player.play().catchError((Object e) {
      if (generation == _generation) _fail(e);
    }));
  }

  @override
  Future<void> play() {
    if (error != null) return retry();
    return _enqueue((generation) async {
      if (!_active || error != null) return;
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      _start(generation);
    });
  }

  @override
  Future<void> pause() => _enqueue((_) async {
        await player.pause();
      });
  @override
  Future<void> seek(Duration position) => _enqueue((_) async {
        if (!_active || error != null) return;
        final duration = player.duration;
        final milliseconds = position.inMilliseconds.clamp(
            0,
            duration?.inMilliseconds ??
                position.inMilliseconds.clamp(0, 1 << 53));
        await player.seek(Duration(milliseconds: milliseconds.toInt()));
      });
  @override
  Future<void> skipToQueueItem(int index) {
    if (!_active || index < 0 || index >= _songs.length) {
      return Future<void>.value();
    }
    if (index == this.index) return Future<void>.value();
    final targetUri = mediaUri(_songs[index].audioUrl!);
    if (targetUri.scheme == 'https') {
      return open(List<Song>.of(_songs), _songs[index], force: true);
    }
    if (error != null) {
      return open(List<Song>.of(_songs), _songs[index], force: true);
    }
    return _enqueue((generation) async {
      if (!_active || index < 0 || index >= _songs.length) return;
      error = null;
      await player.seek(Duration.zero, index: index);
      _start(generation);
    });
  }

  @override
  Future<void> skipToNext() => skipToQueueItem(index + 1);
  @override
  Future<void> skipToPrevious() => skipToQueueItem(index - 1);
  @override
  Future<void> onTaskRemoved() async {
    welcomeOnNextOpen = true;
    await stop();
  }

  @override
  Future<void> stop() {
    ++_generation; // Cancel queued loads/plays from the previous session.
    _active = false;
    loading = false;
    error = null;
    _songs = const [];
    queue.add(const []);
    mediaItem.add(null);
    _publish();
    // Stop immediately as well, so an in-flight load can be interrupted.
    final cancel = player.stop().catchError((Object _) {});
    return _enqueue((generation) async {
      await cancel;
      if (generation != _generation) return;
      await player.stop();
      _publish();
    });
  }
}
