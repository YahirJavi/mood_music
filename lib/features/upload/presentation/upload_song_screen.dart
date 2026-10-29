import '../../../core/validation/form_validators.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:moodmusic_local_media/moodmusic_local_media.dart';
import '../../catalog/domain/music_genres.dart';
import '../../catalog/domain/music_moods.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../app/app_controller.dart';
import '../../catalog/domain/song.dart';
import '../../catalog/presentation/song_cover.dart';
import '../data/local_file_picker.dart';

class UploadSongScreen extends StatefulWidget {
  const UploadSongScreen({super.key, required this.controller, this.song});
  final AppController controller;
  final Song? song;
  @override
  State<UploadSongScreen> createState() => _UploadSongScreenState();
}
class _UploadSongScreenState extends State<UploadSongScreen> {
  late final String? _owner = widget.controller.userId;
  late final _repository = widget.controller.localCatalog;
  bool get _allowed => widget.controller.canManageMusic && widget.controller.userId == _owner && identical(widget.controller.localCatalog, _repository);
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.song?.title);
  late final _artist = TextEditingController(text: widget.song?.artist);
  late String? _genre = widget.song?.genre;
  late final Set<String> _moods = {...?widget.song?.moods};
  String _status = '';
  String? _audioName;
  int? _audioBytes;
  File? _audio, _cover;
  bool _busy = false;
  String? _error;
  Future<void> _pick(bool cover, {bool video = false}) async {
    setState(() { _busy = true; _error = null; _status = video ? 'Seleccionando video…' : 'Seleccionando archivo…'; });
    try {
      var file = await LocalFilePicker.pick(cover: cover, video: video);
      final sourceName = file?.uri.pathSegments.last;
      if (file != null && video) {
        final source = file;
        if (mounted) setState(() => _status = 'Extrayendo el sonido del video…');
        try { file = File(await MoodMusicLocalMedia.extractAudio(source.path)); }
        finally { await LocalFilePicker.release(source); }
      }
      if (!mounted) { await LocalFilePicker.release(file); return; }
      if (file != null) {
        final bytes = cover ? null : await file.length();
        if (!mounted || !_allowed) {
          await LocalFilePicker.release(file);
          return;
        }
        final previous = cover ? _cover : _audio;
        if (cover) { _cover = file; } else {
          _audio = file;
          _audioName = video ? '$sourceName → audio.m4a' : sourceName;
          _audioBytes = bytes;
        }
        await LocalFilePicker.release(previous);
      }
    } on PlatformException catch (error) {
      if (mounted) _error = error.message ?? 'No se pudo extraer el audio de este video.';
    } on MissingPluginException {
      if (mounted) _error = 'La función de video no está disponible. Cierra la app y vuelve a intentarlo.';
    } catch (_) { if (mounted) _error = 'No se pudo leer el archivo. Límites: audio 100 MB, video 300 MB y portada 5 MB.'; }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_audio == null && widget.song == null) { setState(() => _error = 'Selecciona un archivo de audio.'); return; }
    setState(() { _busy = true; _error = null; _status = 'Comprobando y guardando audio…'; });
    try {
      if (!_allowed) throw StateError('Sin permiso');
      if (_audio != null) {
        await widget.controller.audio?.pause();
        final probe = AudioPlayer();
        try { await probe.setFilePath(_audio!.path).timeout(const Duration(seconds: 20)); }
        finally { await probe.dispose(); }
      }
      if (!mounted) return;
      if (!_allowed) throw StateError('Sin permiso');
      final repo = _repository!;
      if (widget.song != null) await widget.controller.audio?.stop();
      if (!_allowed) throw StateError('Sin permiso');
      await repo.save(existing: widget.song, title: _title.text, artist: _artist.text,
        genre: _genre!, moods: _moods.toList(), audio: _audio, cover: _cover);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Comprueba que el audio se pueda reproducir, que tengas espacio y que sigas conectado a tu cuenta.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() {
    _title.dispose(); _artist.dispose();
    unawaited(LocalFilePicker.release(_audio)); unawaited(LocalFilePicker.release(_cover));
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.controller,
    builder: (context, _) => PopScope(canPop: !_busy, child: Scaffold(
      appBar: AppBar(title: Text(widget.song == null ? 'Agregar canción' : 'Editar canción')),
      body: !_allowed ? const Center(child: Text('Vuelve a Mi música para abrir la biblioteca de tu cuenta.')) :
      SafeArea(child: Align(alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620),
      child: Form(key: _form, child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        Center(child: SongCover(path: _cover?.path ?? widget.song?.coverUrl, size: 180)),
        TextButton.icon(onPressed: _busy ? null : () => _pick(true), icon: const Icon(Icons.image_outlined), label: const Text('Elegir portada')),
        const SizedBox(height: 16),
        for (final field in [(controller: _title, label: 'Título'), (controller: _artist, label: 'Artista')])
          Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller: field.controller,
            enabled: !_busy, maxLength: 30, decoration: InputDecoration(labelText: field.label),
            validator: identical(field.controller, _artist) ? validateArtist : validateSongTitle)),
        DropdownButtonFormField<String>(
          initialValue: _genre, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Género'),
          items: genreOptions(widget.song?.genre).map((genre) => DropdownMenuItem(value: genre, child: Text(genre))).toList(),
          onChanged: _busy ? null : (value) => setState(() => _genre = value),
          validator: (value) => value == null ? 'Selecciona un género.' : null,
        ),
        const SizedBox(height: 16),
        Text('Estados de ánimo (opcional)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: musicMoods.map((mood) => FilterChip(
          label: Text(mood), selected: _moods.contains(mood),
          onSelected: _busy ? null : (selected) => setState(() {
            if (selected) { _moods.add(mood); } else { _moods.remove(mood); }
          }),
        )).toList()),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: _busy ? null : () => _pick(false), icon: const Icon(Icons.audio_file_outlined),
          label: Text(_audio != null ? 'Audio seleccionado · Cambiar' : widget.song != null ? 'Reemplazar audio (opcional)' : 'Seleccionar audio')),
        if (_audio != null) Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.audio_file, color: Colors.green),
            const SizedBox(height: 8),
            Text(_audioName ?? 'Audio', softWrap: true),
            if (_audioBytes != null) Text('${(_audioBytes! / 1048576).toStringAsFixed(1)} MB'),
            const SizedBox(height: 8),
            const LinearProgressIndicator(value: 1),
            const SizedBox(height: 8),
            const Text('Archivo listo. Pulsa Guardar canción para añadirlo a tu biblioteca.'),
          ]),
        )),
        const SizedBox(height: 8), const Text('MP3, M4A, AAC, WAV, OGG o FLAC · hasta 100 MB'),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _busy ? null : () => _pick(false, video: true),
          icon: const Icon(Icons.video_file_outlined), label: const Text('Extraer audio de un video', textAlign: TextAlign.center)),
        const Text('Video · hasta 300 MB'),
        const SizedBox(height: 8),
        const Text('Después de guardarlo: Mi música → menú de la canción → Exportar audio.'),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        if (_busy) ...[Text(_status), const SizedBox(height: 8), const LinearProgressIndicator()],
        FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Guardar canción')),
      ]))))),
    )),
  );
}
