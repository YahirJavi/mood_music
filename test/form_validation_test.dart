import 'package:flutter_test/flutter_test.dart';
import 'package:mood_music/core/validation/form_validators.dart';
import 'package:mood_music/features/auth/domain/password_policy.dart';

void main() {
  test('Nombre admite acentos y rechaza números y signos', () {
    for (final value in ['Yahir Javier', 'María José', 'Íñigo', 'Jose\u0301']) {
      expect(validatePersonName(value), isNull, reason: value);
    }
    for (final value in ['', '   ', 'Yahir123', 'Ana!', 'Ana\nMaría', 'a' * 41]) {
      expect(validatePersonName(value), isNotNull, reason: value);
    }
  });
  test('Contraseña de registro de 8 a 20 caracteres', () {
    expect(validateNewPassword('Clave12!'), isNull);
    expect(validateNewPassword('${'a' * 18}1!'), isNull);
    expect(validateNewPassword('${'a' * 19}1!'), isNotNull);
    expect(validateNewPassword('Abc12!'), isNotNull);
    expect(validateNewPassword('clave123'), isNotNull);
  });
  test('Artistas conservan nombres reales con puntuación o números', () {
    for (final value in ['Coldplay', 'AC/DC', 'blink-182', 'Zoé', 'Guns N’ Roses', 'P!nk']) {
      expect(validateArtist(value), isNull, reason: value);
    }
    for (final value in ['', '   ', '12345', '!!!', '<script>', 'Ana\nMaría', 'a' * 31]) {
      expect(validateArtist(value), isNotNull, reason: value);
    }
  });
  test('Título y artista aceptan 30 caracteres y rechazan 31', () {
    expect(validateSongTitle('a' * 30), isNull);
    expect(validateArtist('a' * 30), isNull);
    expect(validateSongTitle('a' * 31), isNotNull);
    expect(validateArtist('a' * 31), isNotNull);
  });
  test('Títulos admiten números y no solo signos', () {
    for (final value in ['Viva la Vida', '505', '¿Dónde estás?', 'Song (Live)']) {
      expect(validateSongTitle(value), isNull, reason: value);
    }
    for (final value in ['', '!!!', '  ', 'a' * 31, 'Hola\nHola']) {
      expect(validateSongTitle(value), isNotNull, reason: value);
    }
  });
}
