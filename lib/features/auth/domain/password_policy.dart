/// Applies to new registrations. Existing accounts keep their login password.
String? validateNewPassword(String? value) {
  if (value == null || value.length < 8 || value.length > 20) {
    return 'Usa entre 8 y 20 caracteres.';
  }
  if (!RegExp(r'[a-zA-Z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value) ||
      !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value)) {
    return 'Incluye una letra, un número y un símbolo.';
  }
  return null;
}
