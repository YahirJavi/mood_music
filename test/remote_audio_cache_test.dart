import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mood_music/features/player/data/remote_audio_cache.dart';

void main() {
  test('La longitud comprimida no invalida el audio descomprimido', () async {
    final directory = await Directory.systemTemp.createTemp('audio_gzip_');
    try {
      final cache = RemoteAudioCache(
        directoryProvider: () async => directory,
        download: (_) async => RemoteAudioResponse(
          statusCode: 200, contentLength: 2, decompressed: true,
          body: Stream<List<int>>.value([1, 2, 3, 4]),
        ),
      );
      final file = await cache.resolve(Uri.parse('https://example.com/song.mp3'));
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
    } finally { await directory.delete(recursive: true); }
  });

  test('Una descarga incompleta se limpia y se vuelve a descargar', () async {
    final directory = await Directory.systemTemp.createTemp('audio_retry_');
    var calls = 0;
    try {
      final cache = RemoteAudioCache(
        directoryProvider: () async => directory,
        download: (_) async {
          calls++;
          return RemoteAudioResponse(statusCode: 200, contentLength: 4,
            body: Stream<List<int>>.value(calls == 1 ? [1] : [1, 2, 3, 4]));
        },
      );
      final file = await cache.resolve(Uri.parse('https://example.com/song.mp3'));
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
      expect(calls, 2);
      expect(await File('${file.path}.part').exists(), isFalse);
    } finally { await directory.delete(recursive: true); }
  });

  test('Descarga el audio remoto una vez y reutiliza el archivo completo',
      () async {
    final directory = await Directory.systemTemp.createTemp('audio_cache_');
    var requests = 0;

    try {
      final cache = RemoteAudioCache(
        directoryProvider: () async => directory,
        download: (_) async {
          requests++;
          return RemoteAudioResponse(
            statusCode: HttpStatus.ok,
            contentLength: 4,
            body: Stream<List<int>>.value([1, 2, 3, 4]),
          );
        },
      );
      final uri = Uri.parse('https://example.com/song.mp3');
      final first = await cache.resolve(uri);
      final second = await cache.resolve(uri);

      expect(first.path, second.path);
      expect(await first.readAsBytes(), [1, 2, 3, 4]);
      expect(requests, 1);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
