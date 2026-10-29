import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodmusic_local_media/moodmusic_local_media.dart';
import '../../../core/widgets/feedback.dart';

Future<void> showAudioExport(BuildContext context, {
  required String path, required String title,
  required bool Function() isAllowed,
}) async {
  if (!isAllowed()) return;
  final saved = await showModalBottomSheet<bool>(
    context: context, isScrollControlled: true,
    isDismissible: false, enableDrag: false, showDragHandle: true,
    builder: (_) => _ExportSheet(path: path, title: title, isAllowed: isAllowed),
  );
  if (saved == true && context.mounted) {
    showMessage(context, 'Audio guardado en la ubicación elegida.');
  }
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.path, required this.title, required this.isAllowed});
  final String path, title;
  final bool Function() isAllowed;
  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}
class _ExportSheetState extends State<_ExportSheet> {
  bool _busy = false;
  String? _message;
  Future<void> _export() async {
    if (_busy) return;
    if (!widget.isAllowed()) {
      setState(() => _message = 'La sesión cambió. Vuelve a tu biblioteca.');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final saved = await MoodMusicLocalMedia.exportAudio(widget.path, widget.title);
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context, true);
      } else {
        setState(() => _message = 'No se guardó ninguna copia. Puedes elegir otra ubicación.');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _message = 'Cierra la ejecución anterior y vuelve a compilar la app para activar la exportación.');
      }
    } on PlatformException {
      if (mounted) {
        setState(() => _message = 'No se pudo exportar. Revisa el espacio disponible y vuelve a elegir el destino.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'No se pudo guardar la copia. Inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFCE3C9D)]),
          ),
          child: const Icon(Icons.file_download_outlined, color: Colors.white, size: 32),
        )),
        const SizedBox(height: 18),
        Text('Exportar audio', textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(widget.title, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        const Text('Guarda una copia en Descargas o en otra carpeta. Tu canción seguirá en Mi música.',
          textAlign: TextAlign.center),
        const SizedBox(height: 20),
        if (_busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          const Text('Elige el destino en Android y espera a que termine la copia.',
            textAlign: TextAlign.center),
        ],
        if (_message != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_message!, textAlign: TextAlign.center)),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _busy ? null : _export,
          icon: const Icon(Icons.folder_open),
          label: const Text('Elegir dónde guardar')),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cerrar')),
      ]),
    )),
  );
}
