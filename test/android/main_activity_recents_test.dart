import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs in the project folder, so this path is relative to it.
  String mainActivity() {
    final files = Directory('android/app/src/main/kotlin')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('MainActivity.kt'));
    expect(files, isNotEmpty, reason: 'MainActivity.kt was not found');
    return files.first.readAsStringSync();
  }

  test('the list of recent apps never shows a picture of the screen (Android 13 and above)', () {
    final code = mainActivity();

    expect(code, contains('setRecentsScreenshotEnabled(false)'));
    expect(code, contains('Build.VERSION_CODES.TIRAMISU'));
  });

  test('that is decided when the screen is created, before the first frame', () {
    final code = mainActivity();
    final onCreate = code.indexOf('override fun onCreate');
    final recents = code.indexOf('setRecentsScreenshotEnabled(false)');

    expect(onCreate, greaterThanOrEqualTo(0));
    expect(recents, greaterThan(onCreate));
  });

  test('the option that blocks screenshots is still there', () {
    final code = mainActivity();

    expect(code, contains('FLAG_SECURE'));
    expect(code, contains('"finly/screen_protection"'));
  });
}
