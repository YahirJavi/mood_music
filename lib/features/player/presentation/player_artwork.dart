import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/music_motion.dart';
import '../../catalog/presentation/song_cover.dart';

class PlayerArtwork extends StatelessWidget {
  const PlayerArtwork({super.key, required this.songId, required this.path, required this.playing, this.fallbackAsset});
  final String songId;
  final String? path;
  final bool playing;
  final String? fallbackAsset;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final size = math.min(constraints.maxWidth - 24, 350.0);
    final reduced = MediaQuery.of(context).disableAnimations;
    return Padding(padding: const EdgeInsets.all(12), child: Center(child: MusicPulse(
      active: playing,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduced ? 0 : 400),
        child: SongCover(key: ValueKey('$songId:$path'), path: path, size: size, fallbackAsset: fallbackAsset)),
      builder: (context, phase, child) {
        final pulse = playing ? (math.sin(phase * math.pi * 2) + 1) / 2 : 0.0;
        return Transform.translate(offset: Offset(0, -pulse * 4),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B5CF6).withAlpha(35 + (pulse * 25).round()),
                  blurRadius: 30, spreadRadius: 3 + pulse * 4),
                BoxShadow(color: const Color(0xFFEC4899).withAlpha(24),
                  blurRadius: 32, offset: const Offset(10, 12)),
              ]),
            child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child)));
      })));
  });
}
