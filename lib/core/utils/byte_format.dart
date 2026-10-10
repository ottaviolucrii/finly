/// A size for the screen: "512 B", "3,4 KB", "12,0 MB".
String formatBytes(int bytes) {
  String one(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${one(bytes / 1024)} KB';
  return '${one(bytes / (1024 * 1024))} MB';
}
