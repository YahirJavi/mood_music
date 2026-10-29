import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../admin/presentation/admin_screen.dart';
import '../../../core/widgets/feedback.dart';
import '../../settings/presentation/settings_screen.dart';
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
    const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)), const SizedBox(height: 18),
    Text(controller.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
    Center(child: Text(controller.isSignedIn ? controller.email ?? 'Cuenta conectada' : 'Perfil de demostración · sin cuenta conectada')), const SizedBox(height: 28),
    if (controller.isSignedIn && controller.profiles != null &&
        (controller.profileSyncing || controller.profileError != null))
      Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(children: [
        if (controller.profileSyncing) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text(controller.profileSyncing
            ? 'Guardando perfil…'
            : controller.profileError ?? '',
            textAlign: TextAlign.center),
        if (controller.profileError != null)
          TextButton.icon(onPressed: controller.profileSyncing ? null : () { controller.syncProfile(); },
            icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      ])),
    ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Editar nombre'), onTap: () async {
      final value = await showDialog<String>(context: context, builder: (_) => _NameDialog(initial: controller.name));
      if (value != null && context.mounted) await runAction(context, () => controller.setName(value));
    }),
    if (controller.isAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings_outlined),
      title: const Text('Panel de administrador'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminScreen(controller: controller)))),
    ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Ajustes'), onTap: () =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(controller: controller)))),
    ListTile(leading: const Icon(Icons.logout), title: Text(controller.isSignedIn ? 'Cerrar sesión' : 'Salir de la demostración'), onTap: () async {
      final owner = controller.userId;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Seguro que quieres salir?'),
          content: const Text('La reproducción se detendrá.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salir')),
          ],
        ),
      );
      if (confirmed != true || !context.mounted || controller.userId != owner) return;
      if (controller.isSignedIn) { runAction(context, controller.signOut); } else { controller.leaveDemo(); }
    }),
  ]);
}
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}
class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController field = TextEditingController(text: widget.initial);
  @override
  void dispose() { field.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Editar nombre'),
    content: TextField(controller: field, maxLength: 40, autofocus: true, onChanged: (_) => setState(() {})),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: field.text.trim().isEmpty ? null : () => Navigator.pop(context, field.text.trim()), child: const Text('Guardar'))]);
}
