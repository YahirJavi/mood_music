import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_music/features/upload/presentation/export_audio_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('moodmusic/local_media');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> openSheet(WidgetTester tester, {bool Function()? isAllowed}) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () => showAudioExport(context,
          path: '/local/cancion.m4a', title: 'Mi canción',
          isAllowed: isAllowed ?? () => true),
        child: const Text('Abrir exportación'),
      )),
    )));
    await tester.tap(find.text('Abrir exportación'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancelar el destino conserva la hoja y permite reintentar', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      expect(call.method, 'exportAudio');
      expect(call.arguments, {'path': '/local/cancion.m4a', 'name': 'Mi canción'});
      return pending.future;
    });
    await openSheet(tester);
    await tester.tap(find.text('Elegir dónde guardar'));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Elegir dónde guardar'));
    expect(button.onPressed, isNull);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(calls, 1);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('No se guardó ninguna copia. Puedes elegir otra ubicación.'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Exportar audio'), findsNothing);
  });

  testWidgets('Solo se confirma la exportación cuando Android devuelve éxito', (tester) async {
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    await openSheet(tester);
    await tester.tap(find.text('Elegir dónde guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Exportar audio'), findsNothing);
    expect(find.text('Audio guardado en la ubicación elegida.'), findsOneWidget);
  });

  testWidgets('El error permite reintentar sin informar un éxito falso', (tester) async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'export');
    });
    await openSheet(tester);
    await tester.tap(find.text('Elegir dónde guardar'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo exportar. Revisa el espacio disponible y vuelve a elegir el destino.'), findsOneWidget);
    expect(find.text('Audio guardado en la ubicación elegida.'), findsNothing);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Si cambia la cuenta no se inicia la copia', (tester) async {
    var allowed = true;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async { calls++; return true; });
    await openSheet(tester, isAllowed: () => allowed);
    allowed = false;
    await tester.tap(find.text('Elegir dónde guardar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('La sesión cambió. Vuelve a tu biblioteca.'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
  });
}
