import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class RemoteAudioResponse {
  const RemoteAudioResponse({
    required this.statusCode,
    required this.contentLength,
    required this.body,
    this.close,
    this.decompressed = false,
  });

  final int statusCode;
  final int contentLength;
  final bool decompressed;
  final Stream<List<int>> body;
  final Future<void> Function()? close;
}

class RemoteAudioCache {
  RemoteAudioCache({
    Future<Directory> Function()? directoryProvider,
    Future<RemoteAudioResponse> Function(Uri uri)? download,
  })  : _directoryProvider = directoryProvider ?? getTemporaryDirectory,
        _downloadRemote = download ?? _request;

  final Future<Directory> Function() _directoryProvider;
  final Future<RemoteAudioResponse> Function(Uri uri) _downloadRemote;
  final Map<String, Future<File>> _pending = {};

  Future<File> resolve(Uri uri) {
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Se requiere una URL HTTP válida.');
    }

    final key = sha256.convert(utf8.encode(uri.toString())).toString();
    return _pending.putIfAbsent(key, () {
      final download = _downloadWithRetry(uri, key);
      return download.whenComplete(() {
        _pending.remove(key);
      });
    });
  }

  Future<File> _downloadWithRetry(Uri uri, String key) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _download(uri, key);
      } on SocketException {
        if (attempt >= 1) rethrow;
      } on FormatException {
        if (attempt >= 1) rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<File> _download(Uri uri, String key) async {
    final directory =
        Directory('${(await _directoryProvider()).path}/mood_music_audio');
    await directory.create(recursive: true);

    final extension = _audioExtension(uri);
    final target = File('${directory.path}/$key$extension');
    if (await target.exists() && await target.length() > 0) return target;

    final partial = File('${target.path}.part');
    final response =
        await _downloadRemote(uri).timeout(const Duration(seconds: 60));
    IOSink? sink;
    try {
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'El servidor respondió ${response.statusCode} al descargar el audio.',
          uri: uri,
        );
      }

      sink = partial.openWrite();
      var receivedBytes = 0;
      await for (final chunk
          in response.body.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        receivedBytes += chunk.length;
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (receivedBytes == 0 ||
          (!response.decompressed && response.contentLength >= 0 &&
              receivedBytes != response.contentLength)) {
        throw const FormatException('La descarga del audio llegó incompleta.');
      }
      if (await target.exists()) await target.delete();
      return await partial.rename(target.path);
    } catch (_) {
      if (sink != null) {
        try { await sink.close(); } catch (_) {}
      }
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      await response.close?.call();
    }
  }

  static Future<RemoteAudioResponse> _request(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 25));
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      return RemoteAudioResponse(
        statusCode: response.statusCode,
        contentLength: response.contentLength,
        decompressed: response.compressionState == HttpClientResponseCompressionState.decompressed,
        body: response,
        close: () async => client.close(force: true),
      );
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  String _audioExtension(Uri uri) {
    final match = RegExp(r'\.(mp3|m4a|aac|wav|ogg|flac)$',
            caseSensitive: false)
        .firstMatch(uri.path);
    return match == null ? '.audio' : '.${match.group(1)!.toLowerCase()}';
  }
}
