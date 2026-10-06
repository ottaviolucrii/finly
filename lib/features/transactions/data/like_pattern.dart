/// Escapes the characters that mean something in a LIKE pattern, so that what
/// the user types in the search box is matched literally.
String escapeLikePattern(String text) {
  return text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}