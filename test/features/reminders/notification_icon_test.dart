import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs in the project folder, so these paths are relative to it.
  final drawable = File('android/app/src/main/res/drawable/ic_stat_finly.xml');
  final keep = File('android/app/src/main/res/raw/keep.xml');

  String remindersCode() {
    final buffer = StringBuffer();
    for (final entity in Directory('lib/features/reminders').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        buffer.writeln(entity.readAsStringSync());
      }
    }
    return buffer.toString();
  }

  test('the reminders use the one-colour icon in the status bar', () {
    final code = remindersCode();

    expect(code, contains('@drawable/ic_stat_finly'));
  });

  test('the reminders no longer use the launcher icon, which has colours', () {
    expect(remindersCode(), isNot(contains('@mipmap/ic_launcher')));
  });

  test('the icon file exists', () {
    expect(drawable.existsSync(), isTrue);
  });

  test('the icon is a vector in one colour, 24 by 24', () {
    final xml = drawable.readAsStringSync();

    expect(xml, contains('<vector'));
    expect(xml, contains('android:width="24dp"'));
    expect(xml, contains('android:height="24dp"'));
    // One colour only: a status bar icon is drawn from its shape.
    expect('android:fillColor'.allMatches(xml).length, 1);
    expect(xml, contains('#FFFFFFFF'));
  });

  test('the icon has the shield and the arrow cut out of it', () {
    final xml = drawable.readAsStringSync();

    expect(xml, contains('android:fillType="evenOdd"'));
    // Two shapes in one path: the shield, then the arrow that becomes the hole.
    final data = RegExp(r'android:pathData="([^"]+)"').firstMatch(xml)!.group(1)!;
    expect('M'.allMatches(data).length, 2);
    expect('Z'.allMatches(data).length, 2);
  });

  test('the build is told to keep the icon, because it is found by its name', () {
    expect(keep.existsSync(), isTrue);
    expect(keep.readAsStringSync(), contains('tools:keep="@drawable/ic_stat_finly"'));
  });
}
