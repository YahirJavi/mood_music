import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mood_music/features/catalog/domain/song.dart';
import 'package:mood_music/features/player/data/music_audio_handler.dart';

class _Player extends Fake implements AudioPlayer {
  final errors = StreamController<PlayerException>.broadcast(sync: true);
  int selected = 0;
  Duration at = Duration.zero;
  Completer<Duration?>? pendingLoad;
  final loads = <Map<Symbol, dynamic>>[];
  int stops = 0;
  List<AudioSource> sources = const [];
  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<PlayerException> get errorStream => errors.stream;
  @override
  int? get currentIndex => selected;
  @override
  Duration? get duration => const Duration(minutes: 4);
  @override
  Duration get position => at;
  @override
  Duration get bufferedPosition => at;
  @override
  double get speed => 1;
  @override
  bool get playing => false;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> seek(Duration? position, {int? index}) async {
    at = position ?? Duration.zero;
    selected = index ?? selected;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #setAudioSources) {
      sources =
          (invocation.positionalArguments.first as List).cast<AudioSource>();
      loads.add(invocation.namedArguments);
      selected = invocation.namedArguments[#initialIndex] as int? ?? 0;
      at = invocation.namedArguments[#initialPosition] as Duration? ??
          Duration.zero;
      return pendingLoad?.future ?? Future<Duration?>.value(duration);
    }
    return super.noSuchMethod(invocation);
  }
}

const first = Song(
    id: 'a',
    title: 'Primera',
    artist: 'Artista',
    genre: 'Rock',
    audioUrl: '/a.mp3');
const second = Song(
    id: 'b',
    title: 'Segunda',
    artist: 'Artista',
    genre: 'Rock',
    audioUrl: '/b.mp3');
const remote = Song(
    id: 'remote',
    title: 'Remota',
    artist: 'Artista',
    genre: 'Rock',
    audioUrl: 'https://example.com/song.mp3');
const bundledSong = Song(
    id: 'shared_demo_01',
    title: 'Viva la Vida',
    artist: 'Coldplay',
    genre: 'Rock',
    audioUrl:
        'https://moodmusic-4b6b7-audio.web.app/audio/viva-la-vida.mp3');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('El audio HTTPS seleccionado se reproduce desde el archivo local',
      () async {
    final player = _Player();
    final directory = await Directory.systemTemp.createTemp('remote_audio_');
    final audioFile = File('${directory.path}/song.mp3');
    await audioFile.writeAsBytes([1, 2, 3]);
    final handler = MusicAudioHandler(
        audioPlayer: player, resolveRemoteAudio: (_) async => audioFile);
    await handler.open([remote], remote);
    expect(player.sources.single, isA<UriAudioSource>());
    expect((player.sources.single as UriAudioSource).uri, audioFile.uri);
    await handler.stop();
    await player.errors.close();
    await directory.delete(recursive: true);
  });

  test('Viva la Vida reproduce el MP3 incluido dentro de la aplicación',
      () async {
    final player = _Player();
    var networkRequested = false;
    final handler = MusicAudioHandler(
        audioPlayer: player,
        resolveRemoteAudio: (_) async {
          networkRequested = true;
          throw StateError('Viva la Vida no debe descargarse de Firebase.');
        });

    await handler.open([bundledSong], bundledSong);

    expect(player.sources.single, isA<UriAudioSource>());
    expect((player.sources.single as UriAudioSource).uri,
        Uri.parse('asset:///hosting_audio/audio/viva-la-vida.mp3'));
    expect(networkRequested, isFalse);
    await handler.stop();
    await player.errors.close();
  });

  test('Al saltar a otra canción HTTPS también se descarga antes de cargarla',
      () async {
    final player = _Player();
    final directory = await Directory.systemTemp.createTemp('remote_audio_');
    final audioFile = File('${directory.path}/next.mp3');
    await audioFile.writeAsBytes([1, 2, 3]);
    var resolvedUrl = Uri();
    final handler = MusicAudioHandler(
        audioPlayer: player,
        resolveRemoteAudio: (uri) async {
          resolvedUrl = uri;
          return audioFile;
        });

    await handler.open([first, remote], first);
    await handler.skipToQueueItem(1);

    expect(resolvedUrl, Uri.parse('https://example.com/song.mp3'));
    expect(handler.currentSong?.id, 'remote');
    expect((player.sources[1] as UriAudioSource).uri, audioFile.uri);
    await handler.stop();
    await player.errors.close();
    await directory.delete(recursive: true);
  });

  test('Reintentar recarga la canción actual y conserva la posición', () async {
    final player = _Player();
    final handler = MusicAudioHandler(audioPlayer: player);
    await handler.open([first, second], first);
    await handler.skipToQueueItem(1);
    player.at = const Duration(seconds: 102);
    player.errors.add(PlayerException(0, 'network failure', player.selected));
    expect(handler.error, isNotNull);
    await handler.retry();
    expect(handler.currentSong?.id, 'b');
    expect(player.loads.last[#initialPosition], const Duration(seconds: 102));
    expect(handler.error, isNull);
    expect(handler.loading, isFalse);
    await handler.stop();
    await player.errors.close();
  });

  testWidgets('Una carga sin respuesta libera la cola y permite reintentar',
      (tester) async {
    final player = _Player();
    final pending = Completer<Duration?>();
    player.pendingLoad = pending;
    final handler = MusicAudioHandler(audioPlayer: player);
    final opening = handler.open([first], first);
    await tester.pump();
    expect(handler.loading, isTrue);
    await tester.pump(const Duration(seconds: 91));
    await opening;
    expect(handler.loading, isFalse);
    expect(handler.error, contains('tardó demasiado'));
    player.pendingLoad = null;
    await handler.retry();
    expect(handler.error, isNull);
    pending.complete(const Duration(minutes: 4));
    await tester.pump();
    expect(handler.error, isNull);
    await handler.stop();
    await player.errors.close();
  });

  test('Quitar la tarea detiene el audio y marca la bienvenida', () async {
    final player = _Player();
    final handler = MusicAudioHandler(audioPlayer: player);
    await handler.open([first], first);
    await handler.onTaskRemoved();
    expect(handler.currentSong, isNull);
    expect(handler.songs, isEmpty);
    expect(handler.welcomeOnNextOpen, isTrue);
    expect(player.stops, greaterThan(0));
    await player.errors.close();
  });

  test('Buscar posición limita el destino a la duración', () async {
    final player = _Player();
    final handler = MusicAudioHandler(audioPlayer: player);
    await handler.open([first], first);
    await handler.seek(const Duration(minutes: 8));
    expect(player.at, const Duration(minutes: 4));
    await handler.seek(const Duration(seconds: -3));
    expect(player.at, Duration.zero);
    await handler.stop();
    await player.errors.close();
  });
}
