import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_music/features/auth/domain/auth_repository.dart';
import 'package:mood_music/features/auth/presentation/register_screen.dart';

class _Auth implements AuthRepository {
  int registrations = 0;
  @override
  Future<void> register(String name, String email, String password) async { registrations++; }
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signInWithProvider(AuthProvider provider) async {}
}
void main() {
  testWidgets('Contraseñas diferentes bloquean el registro; iguales permiten enviarlo', (tester) async {
    final repository = _Auth();
    await tester.pumpWidget(MaterialApp(home: RegisterScreen(repository: repository)));
    // Completa la entrada sin esperar al emblema que se anima en bucle.
    await tester.pump(const Duration(milliseconds: 700));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Yahir');
    await tester.enterText(fields.at(1), 'yahir@example.com');
    await tester.enterText(fields.at(2), 'Clave123!');
    await tester.enterText(fields.at(3), 'distinta123');
    final button = find.widgetWithText(FilledButton, 'Crear cuenta');
    await tester.ensureVisible(button); await tester.tap(button); await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(repository.registrations, 0);
    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), 'Clave123!');
    await tester.ensureVisible(button); await tester.tap(button); await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.registrations, 1);
  });
}
