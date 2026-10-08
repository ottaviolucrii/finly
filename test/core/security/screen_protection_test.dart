import 'dart:io';

import 'package:finly/core/security/screen_protection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(screenProtectionChannelName);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('the channel has the name the Android side uses', () {
    expect(screenProtectionChannelName, 'finly/screen_protection');
  });

  group('PlatformScreenProtection', () {
    test('reads whether the protection is on', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'isEnabled');
        return true;
      });

      expect(await PlatformScreenProtection().isEnabled(), isTrue);
    });

    test('reads that it is off', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);

      expect(await PlatformScreenProtection().isEnabled(), isFalse);
    });

    test('an answer with nothing in it counts as off', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      expect(await PlatformScreenProtection().isEnabled(), isFalse);
    });

    test('says null when there is no Android side (iOS, a computer, a test)', () async {
      // No handler at all: the call finds nothing on the other end.
      expect(await PlatformScreenProtection().isEnabled(), isNull);
    });

    test('turns it on, telling the Android side', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return null;
      });

      await PlatformScreenProtection().setEnabled(true);

      expect(received!.method, 'setEnabled');
      expect(received!.arguments, {'enabled': true});
    });

    test('turns it off', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return null;
      });

      await PlatformScreenProtection().setEnabled(false);

      expect(received!.arguments, {'enabled': false});
    });

    test('a refusal of the Android side is an error for whoever asked', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'denied');
      });

      await expectLater(PlatformScreenProtection().setEnabled(true), throwsA(isA<PlatformException>()));
    });
  });

  group('the Android side', () {
    String mainActivity() {
      final files = Directory('android/app/src/main/kotlin')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('MainActivity.kt'));
      expect(files, isNotEmpty, reason: 'MainActivity.kt was not found');
      return files.first.readAsStringSync();
    }

    test('answers on the same channel the app asks on', () {
      expect(mainActivity(), contains('"$screenProtectionChannelName"'));
    });

    test('answers the two calls the app makes', () {
      final code = mainActivity();

      expect(code, contains('"isEnabled"'));
      expect(code, contains('"setEnabled"'));
    });

    test('uses the flag that blocks screenshots, and clears it', () {
      final code = mainActivity();

      expect(code, contains('FLAG_SECURE'));
      expect(code, contains('addFlags'));
      expect(code, contains('clearFlags'));
    });

    test('applies the choice when the app starts, before the first frame', () {
      expect(mainActivity(), contains('override fun onCreate'));
    });

    test('is still the activity the biometric prompt needs', () {
      expect(mainActivity(), contains('FlutterFragmentActivity()'));
    });
  });
}
