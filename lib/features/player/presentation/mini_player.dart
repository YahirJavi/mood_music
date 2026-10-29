import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../catalog/presentation/song_cover.dart';
import 'player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final audio = controller.audio;
    if (audio == null) return const SizedBox.shrink();
    return ListenableBuilder(listenable: audio.changes, builder: (context, _) {
      final song = audio.currentSong;
      if (song == null) return const SizedBox.shrink();
      return Material(color: Theme.of(context).colorScheme.primaryContainer,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: SongCover(path: song.coverUrl, size: 44,
              fallbackAsset: song.id == 'shared_demo_01' ? 'hosting_audio/covers/viva-la-vida.jpg' : null),
            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(audio.error ?? song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PlayerScreen(song: song, controller: controller))),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: audio.isPlaying ? 'Pausar' : 'Reproducir',
                onPressed: audio.loading || audio.error != null ? null : () { if (audio.isPlaying) { audio.pause(); } else { audio.play(); } },
                icon: Icon(audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
              IconButton(tooltip: 'Siguiente canción', onPressed: audio.hasNext && !audio.loading ? audio.skipToNext : null,
                icon: const Icon(Icons.skip_next_rounded)),
              IconButton(tooltip: 'Detener reproducción', onPressed: audio.stop, icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          if (audio.loading) const LinearProgressIndicator(),
        ]),
      );
    });
  }
}
