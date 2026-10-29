import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mood_music/app/app_controller.dart';
import 'package:mood_music/app/app_shell.dart';
import 'package:mood_music/app/mood_music_app.dart';
import 'package:mood_music/core/widgets/launch_intro.dart';
import 'package:mood_music/core/storage/preferences_service.dart';
import 'package:mood_music/features/auth/domain/auth_repository.dart';
import 'package:mood_music/features/auth/presentation/auth_screen.dart';
import 'package:mood_music/features/catalog/data/demo_catalog_repository.dart';

class _Auth implements AuthRepository {
  String? lastPassword;
  @override
  Future<void> register(String name, String email, String password) async {}
  @override
  Future<void> signIn(String email, String password) async { lastPassword = password; }
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signInWithProvider(AuthProvider provider) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('El arranque conserva el login original y permite contraseñas existentes', (tester) async {
    final controller = AppController(await PreferencesService.create(), DemoCatalogRepository());
    final auth = _Auth();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MoodMusicApp(controller: controller, auth: auth));
    expect(find.byType(LaunchIntro), findsOneWidget);
    // El overlay bloquea el login mientras se muestra; después lo libera.
    final blocked = find.ancestor(of: find.byType(AuthScreen), matching: find.byType(IgnorePointer));
    expect(blocked.evaluate().any((e) => (e.widget as IgnorePointer).ignoring), isTrue);
    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(LaunchIntro), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'pruebas@example.com');
    await tester.enterText(fields.at(1), 'clave123');
    final login = find.widgetWithText(FilledButton, 'Iniciar sesión');
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pump();
    expect(auth.lastPassword, 'clave123');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Mi música ocupa su pestaña sin sustituir Inicio ni Favoritos', (tester) async {
    final controller = AppController(await PreferencesService.create(), DemoCatalogRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: AppShell(controller: controller)));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.cast<NavigationDestination>().map((d) => d.label),
      ['Inicio', 'Buscar', 'Mi música', 'Favoritos', 'Perfil']);
    await tester.tap(find.text('Mi música'));
    await tester.pump();
    expect(find.text('Inicia sesión para gestionar tu música.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
