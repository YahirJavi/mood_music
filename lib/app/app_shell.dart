import '../features/player/presentation/mini_player.dart';
import '../features/admin/presentation/local_songs_screen.dart';
import 'package:flutter/material.dart';
import 'app_controller.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../core/widgets/brand.dart';
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Brand(), actions: [IconButton(
      tooltip: 'Ajustes', icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(controller: widget.controller))),
    )]),
    body: IndexedStack(index: index, children: [
      CatalogScreen(controller: widget.controller),
      CatalogScreen(controller: widget.controller, searchPage: true),
      LocalSongsScreen(controller: widget.controller, embedded: true),
      CatalogScreen(controller: widget.controller, favoritesOnly: true),
      ProfileScreen(controller: widget.controller),
    ]),
    bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
      MiniPlayer(controller: widget.controller),
      NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
      NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
      NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Mi música'),
      NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favoritos'),
      NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
    ]),
    ]),
  );
}
