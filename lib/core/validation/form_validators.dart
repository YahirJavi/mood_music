/// Shared form rules. They validate input without silently changing it.
final _letters = RegExp(r'\p{L}', unicode: true);
final _name = RegExp(r'^[\p{L}\p{M}]+(?: +[\p{L}\p{M}]+)*$', unicode: true);
final _artist = RegExp(r"^[\p{L}\p{M}0-9 .,&'’()/+!?:\-]+$", unicode: true);

String? validatePersonName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Escribe tu nombre.';
  if (text.length > 40) return 'Usa un máximo de 40 caracteres.';
  if (!_name.hasMatch(text)) return 'Usa solo letras y espacios en tu nombre.';
  return null;
}

String? validateSongTitle(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Escribe el título de la canción.';
  if (text.length > 30) return 'Usa un máximo de 30 caracteres.';
  if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(text) ||
      !RegExp(r'[\p{L}0-9]', unicode: true).hasMatch(text)) {
    return 'El título debe contener letras o números.';
  }
  return null;
}

String? validateArtist(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Escribe el nombre del artista.';
  if (text.length > 30) return 'Usa un máximo de 30 caracteres.';
  if (!_letters.hasMatch(text) || !_artist.hasMatch(text)) {
    return 'Escribe un nombre de artista válido, no solo números o signos.';
  }
  return null;
}
