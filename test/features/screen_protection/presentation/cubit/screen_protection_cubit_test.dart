import 'dart:async';

import 'package:finly/core/security/screen_protection.dart';
import 'package:finly/features/screen_protection/presentation/cubit/screen_protection_cubit.dart';
import 'package:finly/features/screen_protection/presentation/cubit/screen_protection_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProtection extends Mock implements ScreenProtection {}

void main() {
  late MockProtection protection;

  setUp(() => protection = MockProtection());

  ScreenProtectionCubit build() => ScreenProtectionCubit(protection);

  test('starts loading, with the protection off', () {
    final cubit = build();

    expect(cubit.state.status, ScreenProtectionStatus.loading);
    expect(cubit.state.enabled, isFalse);
    cubit.close();
  });

  group('load', () {
    test('shows the protection as it is on', () async {
      when(() => protection.isEnabled()).thenAnswer((_) async => true);
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, ScreenProtectionStatus.ready);
      expect(cubit.state.enabled, isTrue);
      await cubit.close();
    });

    test('shows the protection as it is off', () async {
      when(() => protection.isEnabled()).thenAnswer((_) async => false);
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, ScreenProtectionStatus.ready);
      expect(cubit.state.enabled, isFalse);
      await cubit.close();
    });

    test('a phone that cannot do it hides the section', () async {
      when(() => protection.isEnabled()).thenAnswer((_) async => null);
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, ScreenProtectionStatus.unsupported);
      await cubit.close();
    });

    test('an error reading it hides the section instead of crashing', () async {
      when(() => protection.isEnabled()).thenThrow(StateError('boom'));
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, ScreenProtectionStatus.unsupported);
      await cubit.close();
    });
  });

  group('setEnabled', () {
    Future<ScreenProtectionCubit> ready({bool enabled = false}) async {
      when(() => protection.isEnabled()).thenAnswer((_) async => enabled);
      final cubit = build();
      await cubit.load();
      return cubit;
    }

    test('moves the switch at once and tells the phone', () async {
      final gate = Completer<void>();
      when(() => protection.setEnabled(any())).thenAnswer((_) => gate.future);
      final cubit = await ready();

      final changing = cubit.setEnabled(true);

      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.saving, isTrue);

      gate.complete();
      await changing;

      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.failed, isFalse);
      verify(() => protection.setEnabled(true)).called(1);
      await cubit.close();
    });

    test('turns it off again', () async {
      when(() => protection.setEnabled(any())).thenAnswer((_) async {});
      final cubit = await ready(enabled: true);

      await cubit.setEnabled(false);

      expect(cubit.state.enabled, isFalse);
      verify(() => protection.setEnabled(false)).called(1);
      await cubit.close();
    });

    test('a refusal of the phone puts the switch back and says so', () async {
      when(() => protection.setEnabled(any())).thenThrow(StateError('refused'));
      final cubit = await ready();

      await cubit.setEnabled(true);

      expect(cubit.state.enabled, isFalse);
      expect(cubit.state.failed, isTrue);
      expect(cubit.state.saving, isFalse);
      await cubit.close();
    });

    test('a second change while one is being saved is ignored', () async {
      final gate = Completer<void>();
      when(() => protection.setEnabled(any())).thenAnswer((_) => gate.future);
      final cubit = await ready();

      final first = cubit.setEnabled(true);
      await cubit.setEnabled(false);
      gate.complete();
      await first;

      verify(() => protection.setEnabled(any())).called(1);
      expect(cubit.state.enabled, isTrue);
      await cubit.close();
    });

    test('the same value does nothing', () async {
      final cubit = await ready(enabled: true);

      await cubit.setEnabled(true);

      verifyNever(() => protection.setEnabled(any()));
      await cubit.close();
    });

    test('does nothing before the phone has been read', () async {
      final cubit = build();

      await cubit.setEnabled(true);

      verifyNever(() => protection.setEnabled(any()));
      await cubit.close();
    });

    test('does nothing on a phone that cannot do it', () async {
      when(() => protection.isEnabled()).thenAnswer((_) async => null);
      final cubit = build();
      await cubit.load();

      await cubit.setEnabled(true);

      verifyNever(() => protection.setEnabled(any()));
      await cubit.close();
    });
  });
}
