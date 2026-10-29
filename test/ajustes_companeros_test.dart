import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mood_music/app/app_controller.dart';
import 'package:mood_music/core/storage/preferences_service.dart';
import 'package:mood_music/features/auth/domain/password_policy.dart';
import 'package:mood_music/features/catalog/data/account_catalog_repository.dart';
import 'package:mood_music/features/catalog/data/demo_catalog_repository.dart';
import 'package:mood_music/features/playlists/presentation/playlists_screen.dart';
import 'package:mood_music/features/profile/presentation/profile_screen.dart';
import 'package:mood_music/features/upload/presentation/upload_song_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Registro exige 8 a 20 caracteres, letra, número y símbolo', () {
    for (final password in [
      '',
      'clave123',
      'clave!!!',
      '1234567!',
      'Ab1!',
      '${'a' * 19}1!',
    ]) {
      expect(validateNewPassword(password), isNotNull, reason: password);
    }
    expect(validateNewPassword('Cancion12!'), isNull);
    expect(validateNewPassword('${'a' * 18}1!'), isNull);
  });

  test(
    'Playlists persisten, evitan duplicados y se separan por cuenta',
    () async {
      final preferences = await PreferencesService.create();
      final controller = AppController(preferences, DemoCatalogRepository());
      addTearDown(controller.dispose);
      controller.userId = 'uno';
      await controller.savePlaylist(
        uid: 'uno',
        title: ' Mi lista ',
        songs: ['a', 'a', 'b'],
      );
      final id = controller.playlists.single.id;
      expect(controller.playlists.single.songIds, ['a', 'b']);
      expect(controller.playlists.single.name, 'Mi lista');
      controller.userId = 'dos';
      expect(controller.playlists, isEmpty);
      await expectLater(
        controller.savePlaylist(uid: 'uno', title: 'No', songs: []),
        throwsStateError,
      );
      await controller.savePlaylist(uid: 'dos', title: 'Otra', songs: ['c']);
      controller.userId = 'uno';
      await controller.savePlaylist(
        uid: 'uno',
        id: id,
        title: 'Editada',
        songs: ['b'],
      );
      expect(
        (await PreferencesService.create()).playlistsFor('uno').single.name,
        'Editada',
      );
      await controller.deletePlaylist('uno', id);
      expect(controller.playlists, isEmpty);
      expect(preferences.playlistsFor('dos').single.name, 'Otra');
    },
  );

  testWidgets('Salir pide confirmación y cancelar conserva la sesión demo', (
    tester,
  ) async {
    final controller = AppController(
      await PreferencesService.create(),
      DemoCatalogRepository(),
    );
    addTearDown(controller.dispose);
    controller.enterDemo();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(controller: controller)),
      ),
    );
    await tester.tap(find.text('Salir de la demostración'));
    await tester.pumpAndSettle();
    expect(find.text('¿Seguro que quieres salir?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(controller.demoOpen, isTrue);
    await tester.tap(find.text('Salir de la demostración'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(controller.demoOpen, isFalse);
  });

  testWidgets('Se crea una playlist desde su formulario', (tester) async {
    final controller = AppController(
      await PreferencesService.create(),
      DemoCatalogRepository(),
    );
    addTearDown(controller.dispose);
    controller.userId = 'uno';
    await tester.pumpWidget(
      MaterialApp(home: PlaylistsScreen(controller: controller)),
    );
    await tester.tap(find.text('Crear playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Para estudiar');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Luces de neón'));
    await tester.scrollUntilVisible(
      find.text('Guardar playlist'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.tap(find.text('Guardar playlist'));
    await tester.pumpAndSettle();
    expect(controller.playlists.single.songIds, ['neon']);
    expect(find.text('Para estudiar'), findsOneWidget);
  });

  testWidgets(
    'Agregar canción cabe con pantalla pequeña, texto grande y teclado',
    (tester) async {
      late Directory root;
      late AccountCatalogRepository catalog;
      late AppController controller;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('music_responsive_');
        catalog = AccountCatalogRepository(root: root);
        controller = AppController(await PreferencesService.create(), catalog)
          ..userId = 'uno';
        await catalog.bind('uno');
      });
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        controller.dispose();
        catalog.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
              viewInsets: const EdgeInsets.only(bottom: 220),
            ),
            child: child!,
          ),
          home: UploadSongScreen(controller: controller),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Guardar canción'),
        150,
        maxScrolls: 40,
        scrollable: find.descendant(
          of: find.byType(UploadSongScreen),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Guardar canción'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
