import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../core/widgets/feedback.dart';
import '../../admin/presentation/admin_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Ajustes')),
            body: ListView(padding: const EdgeInsets.all(24), children: [
              Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                  spacing: 8,
                  children: ThemeMode.values
                      .map((mode) => ChoiceChip(
                            label: Text(switch (mode) {
                              ThemeMode.dark => 'Oscuro',
                              ThemeMode.light => 'Claro',
                              ThemeMode.system => 'Sistema'
                            }),
                            avatar: Icon(
                                switch (mode) {
                                  ThemeMode.system =>
                                    Icons.settings_suggest_outlined,
                                  ThemeMode.light => Icons.light_mode_outlined,
                                  ThemeMode.dark => Icons.dark_mode_outlined,
                                },
                                size: 18,
                                color: mode == ThemeMode.system
                                    ? Colors.blue
                                    : null),
                            selected: controller.themeMode == mode,
                            onSelected: (_) => runAction(
                                context, () => controller.setTheme(mode)),
                          ))
                      .toList()),
              const Divider(height: 40),
              if (controller.adminAccess.loading)
                const LinearProgressIndicator(),
              if (controller.isAdmin)
                ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Panel de administrador'),
                    subtitle: const Text('Consultar usuarios'),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                AdminScreen(controller: controller)))),
              if (controller.adminAccess.error != null)
                ListTile(
                    title: Text(controller.adminAccess.error!),
                    trailing: IconButton(
                        tooltip: 'Reintentar',
                        icon: const Icon(Icons.refresh),
                        onPressed: controller.adminAccess.retry)),
              const ListTile(
                  title: Text('MoodMusic'), subtitle: Text('Versión 1.2.0')),
            ]),
          ));
}
