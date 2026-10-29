import 'package:flutter/services.dart';
class MoodMusicLocalMedia {
  static const _channel = MethodChannel('moodmusic/local_media');
  static Future<bool> exportAudio(String path, String name) async =>
      await _channel.invokeMethod<bool>('exportAudio', {'path': path, 'name': name}) ?? false;
  static Future<String> extractAudio(String path) async {
    final output = await _channel.invokeMethod<String>('extractAudio', {'path': path});
    if (output == null || output.isEmpty) throw PlatformException(code: 'empty-output', message: 'No se generó el audio.');
    return output;
  }
}
