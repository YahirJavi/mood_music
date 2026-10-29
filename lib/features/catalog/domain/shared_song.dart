import 'song.dart';

const _demoCoverUrl =
    'https://moodmusic-4b6b7-audio.web.app/covers/viva-la-vida.jpg';

Song? readSharedSong(Map<String, dynamic>? data) {
  if (data == null || data['enabled'] != true) return null;
  String field(String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty || value.length > 100) {
      throw FormatException('Campo inválido: $key');
    }
    return value.trim();
  }

  final audio = data['audioUrl'];
  final uri = audio is String ? Uri.tryParse(audio) : null;
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const FormatException('Se necesita una URL HTTPS directa al audio.');
  }
  // A missing or invalid optional cover must not hide a playable song.
  final cover = data['coverUrl'];
  final coverUri = cover is String ? Uri.tryParse(cover.trim()) : null;
  final coverUrl = coverUri != null && coverUri.scheme == 'https' &&
      coverUri.host.isNotEmpty && coverUri.userInfo.isEmpty
      ? coverUri.toString() : _demoCoverUrl;
  return Song(id: 'shared_demo_01', title: field('title'), artist: field('artist'),
    genre: field('genre'), audioUrl: uri.toString(), coverUrl: coverUrl);
}
