import 'package:flutter/material.dart';
import 'music_motion.dart';

/// Decorative launch overlay. The original login remains underneath.
class LaunchIntro extends StatelessWidget {
  const LaunchIntro({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: RadialGradient(
          center: const Alignment(0, -.25),
          radius: .95,
          colors: [
            const Color(0xFF8B5CF6).withAlpha(dark ? 38 : 24),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        )),
        child: SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Semantics(label: 'Bienvenido a MoodMusic',
            child: ExcludeSemantics(child: MusicEntrance(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 196, height: 196, child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(width: 190, height: 190,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(30)))),
                    Container(width: 156, height: 156,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          const Color(0xFF8B5CF6).withAlpha(25),
                          const Color(0xFFEC4899).withAlpha(12),
                        ]))),
                    const MusicEmblem(size: 108),
                  ],
                )),
                const SizedBox(height: 18),
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Mood', style: TextStyle(color: text)),
                  const TextSpan(text: 'Music', style: TextStyle(color: Color(0xFF9B66FF))),
                ]), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                const SizedBox(height: 10),
                Text('Tu música. Tu momento.', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: text.withAlpha(180))),
                const SizedBox(height: 30),
                const MusicBars(active: true),
              ],
            ))),
          ),
        ))),
      ),
    );
  }
}
