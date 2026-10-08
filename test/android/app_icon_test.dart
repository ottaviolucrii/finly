import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The width, the height and the colour type of a PNG file, read from its header.
({int width, int height, int colorType}) pngHeader(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(Uint8List.fromList(bytes));

  // A PNG starts with 8 fixed bytes, then the IHDR chunk: width and height at
  // bytes 16 and 20, and the colour type at byte 25 (6 = with transparency).
  expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: '${file.path} is not a PNG');
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: bytes[25],
  );
}

void main() {
  // `flutter test` runs in the project folder, so these paths are relative to it.
  final res = Directory('android/app/src/main/res');

  // Android has one size of each icon for each screen density.
  const legacySizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
  const foregroundSizes = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};

  group('the icon of the app for old phones', () {
    legacySizes.forEach((density, size) {
      test('$density is $size by $size pixels', () {
        final header = pngHeader(File('${res.path}/mipmap-$density/ic_launcher.png'));

        expect(header.width, size);
        expect(header.height, size);
      });
    });
  });

  group('the foreground of the adaptive icon', () {
    foregroundSizes.forEach((density, size) {
      test('$density is $size by $size pixels, with transparency', () {
        final header = pngHeader(File('${res.path}/mipmap-$density/ic_launcher_foreground.png'));

        expect(header.width, size);
        expect(header.height, size);
        expect(header.colorType, 6, reason: 'the foreground must have an alpha channel');
      });
    });
  });

  group('the adaptive icon', () {
    final adaptive = File('${res.path}/mipmap-anydpi-v26/ic_launcher.xml');

    test('has a background, a foreground and a one-colour version', () {
      final xml = adaptive.readAsStringSync();

      expect(xml, contains('<adaptive-icon'));
      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('@mipmap/ic_launcher_foreground'));
      expect(xml, contains('<monochrome android:drawable="@drawable/ic_launcher_monochrome"'));
    });

    test('has a white background, the Clean White of the brand', () {
      final xml = File('${res.path}/values/ic_launcher_background.xml').readAsStringSync();

      expect(xml, contains('name="ic_launcher_background"'));
      expect(xml, contains('#FFFFFF'));
    });

    test('the one-colour version is the shield of the notifications, with room around it', () {
      final xml = File('${res.path}/drawable/ic_launcher_monochrome.xml').readAsStringSync();

      expect(xml, contains('@drawable/ic_stat_finly'));
      expect(xml, contains('android:inset="20%"'));
      expect(File('${res.path}/drawable/ic_stat_finly.xml').existsSync(), isTrue);
    });
  });

  test('the app uses the icon by the name the files have', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
  });
}
