import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_music/features/catalog/domain/shared_song.dart';
import 'package:mood_music/features/catalog/domain/song.dart';
import 'package:mood_music/features/catalog/data/account_catalog_repository.dart';
import 'package:mood_music/features/player/domain/media_uri.dart';

void main() {
  Map<String, dynamic> data() => {
    'enabled': true, 'title': 'Tema compartido', 'artist': 'Autor',
    'genre': 'Pop', 'audioUrl': 'https://example.com/audio.mp3',
  };
  test('identificador compartido estable y audio HTTPS', () {
    final first = readSharedSong(data())!;
    final second = readSharedSong({...data(), 'title': 'Título corregido'})!;
    expect(first.id, 'shared_demo_01');
    expect(first.coverUrl,
        'https://moodmusic-4b6b7-audio.web.app/covers/viva-la-vida.jpg');
    expect(readSharedSong({...data(), 'coverUrl': 'https://example.com/cover.jpg'})!.coverUrl,
        'https://example.com/cover.jpg');
    expect(readSharedSong({...data(), 'coverUrl': '/private/cover.jpg'})!.coverUrl,
        'https://moodmusic-4b6b7-audio.web.app/covers/viva-la-vida.jpg');
    expect(
        readSharedSong({...data(), 'coverUrl': 123})!.coverUrl,
        'https://moodmusic-4b6b7-audio.web.app/covers/viva-la-vida.jpg');
    expect(second.id, first.id);
    expect(mediaUri(first.audioUrl!).scheme, 'https');
    expect(mediaUri('/tmp/song.mp3').scheme, 'file');
    expect(readSharedSong(null), isNull);
    expect(readSharedSong({...data(), 'enabled': false}), isNull);
    expect(() => readSharedSong({...data(), 'audioUrl': '/private/song.mp3'}), throwsFormatException);
    expect(() => readSharedSong({...data(), 'audioUrl': 'http://example.com/song.mp3'}), throwsFormatException);
  });

  test('compartida visible sin mezclarse con el CRUD local y se limpia al salir', () async {
    final root = await Directory.systemTemp.createTemp('shared_music_');
    final stream = StreamController<List<Song>>.broadcast(sync: true);
    final repo = AccountCatalogRepository(root: root, watchShared: () => stream.stream);
    try {
      await repo.bind('alice');
      stream.add([readSharedSong(data())!]);
      expect(repo.songs.single.id, 'shared_demo_01');
      expect(repo.local!.songs, isEmpty);
      final source = File('${root.path}/source.mp3');
      await source.writeAsBytes([1, 2, 3]);
      await repo.local!.save(title: 'Local', artist: 'Yo', genre: 'Pop', audio: source);
      expect(repo.songs.length, 2);
      stream.addError(StateError('sin conexión'));
      expect(repo.sharedError, isNotNull);
      expect(repo.songs.single.title, 'Local');
      await repo.bind(null);
      stream.add([readSharedSong(data())!]);
      expect(repo.songs, isEmpty);
      await repo.bind('bob');
      stream.add([readSharedSong(data())!]);
      expect(repo.songs.single.id, 'shared_demo_01');
      expect(repo.local!.songs, isEmpty);
    } finally {
      repo.dispose();
      await stream.close();
      await root.delete(recursive: true);
    }
  });
}
