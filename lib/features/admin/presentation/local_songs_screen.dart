import 'package:flutter/material.dart';
import '../../playlists/presentation/playlists_screen.dart';
import '../../../app/app_controller.dart';
import '../../../core/widgets/feedback.dart';
import '../../catalog/data/account_catalog_repository.dart';
import '../../catalog/domain/song.dart';
import '../../catalog/presentation/song_cover.dart';
import '../../upload/presentation/upload_song_screen.dart';
import '../../upload/presentation/export_audio_sheet.dart';
class LocalSongsScreen extends StatelessWidget {
  const LocalSongsScreen({super.key, required this.controller, this.embedded = false});
  final AppController controller;
  final bool embedded;
  Future<void> _delete(BuildContext context, Song song) async {
    final owner = controller.userId;
    final repo = controller.localCatalog;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Eliminar canción'), content: Text('¿Eliminar “${song.title}” de tu biblioteca?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))]));
    if (confirmed != true || !context.mounted || !controller.canManageMusic || controller.userId != owner || controller.localCatalog != repo) return;
    await runAction(context, () async {
      await controller.audio?.stop();
      if (!controller.canManageMusic || controller.userId != owner || controller.localCatalog != repo) return;
      await repo!.remove(song);
    });
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: controller, builder: (context, _) => Scaffold(
    appBar: embedded ? null : AppBar(title: const Text('Mi música')),
    floatingActionButton: !controller.canManageMusic ? null : FloatingActionButton.extended(
      onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => UploadSongScreen(controller: controller))),
      icon: const Icon(Icons.add), label: const Text('Agregar canción')),
    body: !controller.canManageMusic ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(!controller.isSignedIn ? 'Inicia sesión para gestionar tu música.' : controller.catalog is AccountCatalogRepository && (controller.catalog as AccountCatalogRepository).loading
          ? 'Abriendo tu biblioteca…' : 'No se pudo abrir tu biblioteca.'),
        if (controller.isSignedIn) TextButton(onPressed: controller.retryLibrary, child: const Text('Reintentar')),
      ])) :
      ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), children: [
        Card(clipBehavior: Clip.antiAlias, child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: const CircleAvatar(backgroundColor: Color(0x228B5CF6),
            child: Icon(Icons.queue_music, color: Color(0xFF9B66FF))),
          title: const Text('Mis playlists', style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => PlaylistsScreen(controller: controller))))),
        if (controller.localCatalog!.songs.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Agrega tu primer audio con el botón de abajo.')),
        ...controller.localCatalog!.songs.map((song) => Card(child: ListTile(
          leading: SongCover(path: song.coverUrl), title: Text(song.title), subtitle: Text('${song.artist} · ${song.genre}'),
          trailing: PopupMenuButton<String>(onSelected: (action) {
            if (action == 'delete') { _delete(context, song); }
            else if (action == 'export') {
              final owner = controller.userId;
              final repository = controller.localCatalog;
              final path = song.audioUrl;
              if (path != null) {
                showAudioExport(context, path: path, title: song.title,
                  isAllowed: () => controller.canManageMusic &&
                    controller.userId == owner && identical(controller.localCatalog, repository));
              }
            }
            else { Navigator.push(context, MaterialPageRoute<void>(builder: (_) => UploadSongScreen(controller: controller, song: song))); }
          }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.file_download_outlined, size: 20), SizedBox(width: 10), Text('Exportar audio')])), PopupMenuItem(value: 'delete', child: Text('Eliminar'))]),
        ))),
      ]),
  ));
}
