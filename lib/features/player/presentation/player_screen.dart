import 'playback_seek_bar.dart';
import '../../activity/presentation/listening_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../app/app_controller.dart';
import '../../../core/widgets/feedback.dart';
import '../../catalog/domain/song.dart';
import '../../../core/widgets/music_motion.dart';
import 'player_artwork.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen(
      {super.key, required this.song, required this.controller, this.playlist});
  final Song song;
  final List<Song>? playlist;
  final AppController controller;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final _audio = widget.controller.audio!;
  AudioPlayer get _player => _audio.player;
  Song get _song => _audio.currentSong ?? widget.song;
  List<Song> get _queue => _audio.songs;
  int get _index => _audio.index;
  bool get _loading => _audio.loading;
  bool get _switching => false;
  String? get _error => _audio.error;
  @override
  void initState() {
    super.initState();
    _audio.changes.addListener(_refresh);
    unawaited(_load());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final requested = widget.playlist;
    if (requested != null && _audio.currentSong?.id == widget.song.id) {
      final playable =
          requested.where((s) => s.audioUrl?.isNotEmpty == true).toList();
      final sameQueue = playable.length == _audio.songs.length &&
          List.generate(
                  playable.length, (i) => playable[i].id == _audio.songs[i].id)
              .every((same) => same);
      if (!sameQueue) {
        await _audio.stop();
      }
    }
    await _audio.open(
        requested ?? widget.controller.catalog.songs, widget.song);
  }

  Future<void> _play() => _audio.play();
  Future<void> _pause() => _audio.pause();
  Future<void> _skip(int delta) => _audio.skipToQueueItem(_index + delta);
  @override
  void dispose() {
    _audio.changes.removeListener(_refresh);
    super.dispose(); // El servicio continúa al cerrar esta pantalla.
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Reproduciendo')),
            body: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: Theme.of(context).brightness == Brightness.dark
                            ? const [
                                Color(0xFF241538),
                                Color(0xFF0B0B14),
                                Color(0xFF211225)
                              ]
                            : const [
                                Color(0xFFF0E8FF),
                                Color(0xFFFAF8FF),
                                Color(0xFFFCE7F3)
                              ])),
                child: SafeArea(
                    top: false,
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 16, 24, 32),
                                children: [
                                  MusicEntrance(
                                      child: PlayerArtwork(
                                          songId: _song.id,
                                          path: _song.coverUrl,
                                          fallbackAsset: _song.id ==
                                                  'shared_demo_01'
                                              ? 'hosting_audio/covers/viva-la-vida.jpg'
                                              : null,
                                          playing: _audio.isPlaying &&
                                              !_loading &&
                                              _error == null &&
                                              _player.processingState ==
                                                  ProcessingState.ready)),
                                  const SizedBox(height: 16),
                                  MusicBars(
                                      active: _audio.isPlaying &&
                                          !_loading &&
                                          _error == null &&
                                          _player.processingState ==
                                              ProcessingState.ready),
                                  const SizedBox(height: 24),
                                  Text(_song.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                  Text(_song.artist),
                                  Row(children: [
                                    Chip(label: Text(_song.genre)),
                                    const Spacer(),
                                    IconButton(
                                        tooltip: 'Cambiar favorito',
                                        onPressed: widget.controller.favoriteSaving(_song)
                                            ? null
                                            : () => runAction(
                                                context,
                                                () => widget.controller
                                                    .toggleFavorite(_song)),
                                        icon: AnimatedSwitcher(
                                            duration: Duration(
                                                milliseconds:
                                                    MediaQuery.of(context).disableAnimations
                                                        ? 0
                                                        : 220),
                                            transitionBuilder: (child, animation) =>
                                                ScaleTransition(
                                                    scale: animation,
                                                    child: child),
                                            child: Icon(
                                                widget.controller.isFavorite(_song)
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                key: ValueKey(widget.controller.isFavorite(_song)),
                                                color: const Color(0xFFEC4899))))
                                  ]),
                                  ListeningNotice(
                                      controller: widget.controller),
                                  if (widget.controller.favoriteSaving(_song))
                                    const Text('Guardando favorito…',
                                        textAlign: TextAlign.center),
                                  if (_audio.currentSong == null)
                                    TextButton(
                                        onPressed: _load,
                                        child:
                                            const Text('Volver a reproducir')),
                                  if (_loading) const LinearProgressIndicator(),
                                  if (_error != null) ...[
                                    Text(_error!, textAlign: TextAlign.center),
                                    TextButton(
                                        onPressed: _loading ? null : () => _audio.currentSong == null ? _load() : _audio.retry(),
                                        child: const Text('Reintentar'))
                                  ],
                                  StreamBuilder<Duration?>(
                                      stream: _player.durationStream,
                                      initialData: _player.duration,
                                      builder: (context, durationSnapshot) {
                                        final duration =
                                            durationSnapshot.data ??
                                                Duration.zero;
                                        return StreamBuilder<Duration>(
                                            stream: _player.positionStream,
                                            initialData: _player.position,
                                            builder:
                                                (context, positionSnapshot) {
                                              final position =
                                                  positionSnapshot.data ??
                                                      Duration.zero;
                                              return PlaybackSeekBar(
                                                key: ValueKey(
                                                    '${_song.id}:${_audio.currentSong?.id}:$_index'),
                                                position: position,
                                                duration: duration,
                                                enabled: !_loading &&
                                                    _error == null &&
                                                    _audio.currentSong != null,
                                                readPosition: () =>
                                                    _player.position,
                                                onSeek: _audio.seek,
                                              );
                                            });
                                      }),
                                  StreamBuilder<PlayerState>(
                                      stream: _player.playerStateStream,
                                      initialData: _player.playerState,
                                      builder: (context, snapshot) {
                                        final state = snapshot.data;
                                        final busy = state?.processingState ==
                                                ProcessingState.loading ||
                                            state?.processingState ==
                                                ProcessingState.buffering;
                                        final playing =
                                            (state?.playing ?? false) &&
                                                state?.processingState !=
                                                    ProcessingState.completed;
                                        return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                  tooltip: 'Canción anterior',
                                                  iconSize: 42,
                                                  onPressed: _loading ||
                                                          _switching ||
                                                          _index <= 0
                                                      ? null
                                                      : () => _skip(-1),
                                                  icon: const Icon(Icons
                                                      .skip_previous_rounded)),
                                              const SizedBox(width: 16),
                                              if (busy || _switching)
                                                const SizedBox(
                                                    width: 80,
                                                    height: 80,
                                                    child: Center(
                                                        child:
                                                            CircularProgressIndicator()))
                                              else
                                                DecoratedBox(
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        gradient:
                                                            const LinearGradient(
                                                                colors: [
                                                              Color(0xFF9B66FF),
                                                              Color(0xFFD946A8)
                                                            ]),
                                                        boxShadow: [
                                                          BoxShadow(
                                                              color: const Color(
                                                                      0xFF9B66FF)
                                                                  .withAlpha(
                                                                      65),
                                                              blurRadius: 22,
                                                              offset:
                                                                  const Offset(
                                                                      0, 6))
                                                        ]),
                                                    child: IconButton(
                                                        style: IconButton.styleFrom(
                                                            foregroundColor:
                                                                Colors.white,
                                                            minimumSize: const Size(
                                                                88, 88)),
                                                        tooltip: playing
                                                            ? 'Pausar'
                                                            : 'Reproducir',
                                                        iconSize: 64,
                                                        onPressed: _loading ||
                                                                _error !=
                                                                    null ||
                                                                _audio.currentSong ==
                                                                    null
                                                            ? null
                                                            : () {
                                                                if (playing) {
                                                                  unawaited(
                                                                      _pause());
                                                                } else {
                                                                  unawaited(
                                                                      _play());
                                                                }
                                                              },
                                                        icon: AnimatedSwitcher(
                                                            duration: Duration(
                                                                milliseconds: MediaQuery.of(context).disableAnimations
                                                                    ? 0
                                                                    : 180),
                                                            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, key: ValueKey(playing))))),
                                              const SizedBox(width: 16),
                                              IconButton(
                                                  tooltip: 'Siguiente canción',
                                                  iconSize: 42,
                                                  onPressed: _loading ||
                                                          _switching ||
                                                          _index >=
                                                              _queue.length - 1
                                                      ? null
                                                      : () => _skip(1),
                                                  icon: const Icon(
                                                      Icons.skip_next_rounded)),
                                            ]);
                                      }),
                                ]))))),
          ));
}
