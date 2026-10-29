import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/widgets/feedback.dart';
import '../../catalog/domain/song.dart';
import '../domain/music_playlist.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key, required this.controller});
  final AppController controller;
  List<Song> _songs(MusicPlaylist playlist) {
    final available = {
      for (final song in controller.catalog.songs) song.id: song,
    };
    return playlist.songIds
        .where(available.containsKey)
        .map((id) => available[id]!)
        .toList();
  }

  void _edit(BuildContext context, [MusicPlaylist? playlist]) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _PlaylistEditor(controller: controller, playlist: playlist),
      ),
    );
  }

  Future<void> _delete(BuildContext context, MusicPlaylist playlist) async {
    final uid = controller.userId;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar playlist'),
        content: Text(
          '¿Eliminar “${playlist.name}”? Tus canciones se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await runAction(
        context,
        () => controller.deletePlaylist(uid, playlist.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Mis playlists')),
      floatingActionButton: controller.isSignedIn
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Crear playlist'),
            )
          : null,
      body: !controller.isSignedIn
          ? const Center(child: Text('Inicia sesión para crear tus playlists.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const Text(
                  'Tus playlists se guardan en este teléfono, dentro de tu cuenta.',
                ),
                const SizedBox(height: 16),
                if (controller.playlists.isEmpty)
                  const Text(
                    'Crea una playlist y agrega las canciones que quieras.',
                  ),
                for (final playlist in controller.playlists)
                  Card(
                    child: ListTile(
                      title: Text(playlist.name),
                      subtitle: Text(
                        '${_songs(playlist).length} canciones disponibles',
                      ),
                      onTap: () => _edit(context, playlist),
                      leading: IconButton(
                        tooltip: 'Reproducir playlist',
                        icon: const Icon(Icons.play_circle),
                        onPressed:
                            _songs(playlist).isEmpty || controller.audio == null
                            ? null
                            : () => runAction(context, () async {
                                final songs = _songs(playlist);
                                if (songs.isEmpty) return;
                                await controller.audio!.open(
                                  songs,
                                  songs.first,
                                );
                                await controller.audio!.play();
                              }),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _delete(context, playlist);
                          } else {
                            _edit(context, playlist);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class _PlaylistEditor extends StatefulWidget {
  const _PlaylistEditor({required this.controller, this.playlist});
  final AppController controller;
  final MusicPlaylist? playlist;
  @override
  State<_PlaylistEditor> createState() => _PlaylistEditorState();
}

class _PlaylistEditorState extends State<_PlaylistEditor> {
  late final String? _owner = widget.controller.userId;
  late final TextEditingController _name = TextEditingController(
    text: widget.playlist?.name,
  );
  late final Set<String> _selected = {...?widget.playlist?.songIds};
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  bool get _allowed => _owner != null && widget.controller.userId == _owner;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_allowed || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Preserve references while a shared song may be temporarily unavailable.
      await widget.controller.savePlaylist(
        uid: _owner!,
        id: widget.playlist?.id,
        title: _name.text,
        songs: _selected.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'No se pudo guardar la playlist. Revisa tu sesión y vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.playlist == null ? 'Crear playlist' : 'Editar playlist',
          ),
        ),
        body: !_allowed
            ? const Center(child: Text('La sesión cambió. Vuelve a Mi música.'))
            : SafeArea(
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la playlist',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Escribe un nombre.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Selecciona tus canciones'),
                      if (widget.controller.catalog.songs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Agrega canciones desde Mi música. Puedes guardar la playlist vacía.',
                          ),
                        ),
                      for (final song in widget.controller.catalog.songs)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(song.title),
                          subtitle: Text(song.artist),
                          value: _selected.contains(song.id),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(song.id);
                                  } else {
                                    _selected.remove(song.id);
                                  }
                                }),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'Guardando…' : 'Guardar playlist',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}
