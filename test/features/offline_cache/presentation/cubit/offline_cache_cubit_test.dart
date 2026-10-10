import 'dart:async';

import 'package:finly/core/offline/cache_store.dart';
import 'package:finly/features/offline_cache/presentation/cubit/offline_cache_cubit.dart';
import 'package:finly/features/offline_cache/presentation/cubit/offline_cache_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStore extends Mock implements CacheStore {}

void main() {
  late MockStore store;

  setUp(() {
    store = MockStore();
    when(() => store.isEnabled()).thenAnswer((_) async => true);
    when(() => store.sizeBytes()).thenAnswer((_) async => 2048);
    when(() => store.setEnabled(any())).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});
  });

  OfflineCacheCubit build() => OfflineCacheCubit(store);

  test('starts not loaded, with the copies on and nothing kept', () {
    final cubit = build();

    expect(cubit.state.loaded, isFalse);
    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.sizeBytes, 0);
    cubit.close();
  });

  group('load', () {
    test('shows whether the copies are on and how much they use', () async {
      final cubit = build();

      await cubit.load();

      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.sizeBytes, 2048);
      await cubit.close();
    });

    test('shows the copies as off when the person turned them off', () async {
      when(() => store.isEnabled()).thenAnswer((_) async => false);
      final cubit = build();

      await cubit.load();

      expect(cubit.state.enabled, isFalse);
      await cubit.close();
    });

    test('a failure to read does not crash and says so', () async {
      when(() => store.sizeBytes()).thenThrow(const FormatException('bad'));
      final cubit = build();

      await cubit.load();

      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.failed, isTrue);
      await cubit.close();
    });
  });

  group('setEnabled', () {
    test('turning them off erases what was kept', () async {
      final cubit = build();
      await cubit.load();
      when(() => store.sizeBytes()).thenAnswer((_) async => 0);

      await cubit.setEnabled(false);

      expect(cubit.state.enabled, isFalse);
      expect(cubit.state.sizeBytes, 0);
      expect(cubit.state.busy, isFalse);
      verifyInOrder([() => store.setEnabled(false), () => store.clear()]);
      await cubit.close();
    });

    test('turning them off counts as an erasing, so the screen says so', () async {
      final cubit = build();
      await cubit.load();

      await cubit.setEnabled(false);

      expect(cubit.state.erased, 1);
      await cubit.close();
    });

    test('turning them on does not erase anything', () async {
      when(() => store.isEnabled()).thenAnswer((_) async => false);
      final cubit = build();
      await cubit.load();

      await cubit.setEnabled(true);

      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.erased, 0);
      verify(() => store.setEnabled(true)).called(1);
      verifyNever(() => store.clear());
      await cubit.close();
    });

    test('the switch moves at once', () async {
      final gate = Completer<void>();
      when(() => store.setEnabled(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load();

      final changing = cubit.setEnabled(false);

      expect(cubit.state.enabled, isFalse);
      expect(cubit.state.busy, isTrue);

      gate.complete();
      await changing;
      await cubit.close();
    });

    test('a failure puts the switch back and says so', () async {
      when(() => store.setEnabled(any())).thenThrow(const FormatException('bad'));
      final cubit = build();
      await cubit.load();

      await cubit.setEnabled(false);

      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.failed, isTrue);
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    });

    test('the same value does nothing', () async {
      final cubit = build();
      await cubit.load();

      await cubit.setEnabled(true);

      verifyNever(() => store.setEnabled(any()));
      await cubit.close();
    });

    test('a second change while one is going on is ignored', () async {
      final gate = Completer<void>();
      when(() => store.setEnabled(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load();

      final first = cubit.setEnabled(false);
      await cubit.setEnabled(true);
      gate.complete();
      await first;

      verify(() => store.setEnabled(any())).called(1);
      await cubit.close();
    });
  });

  group('erase', () {
    test('erases the copies and shows the new size', () async {
      final cubit = build();
      await cubit.load();
      when(() => store.sizeBytes()).thenAnswer((_) async => 0);

      await cubit.erase();

      verify(() => store.clear()).called(1);
      expect(cubit.state.sizeBytes, 0);
      expect(cubit.state.erased, 1);
      expect(cubit.state.enabled, isTrue);
      await cubit.close();
    });

    test('counts each erasing', () async {
      final cubit = build();
      await cubit.load();

      await cubit.erase();
      await cubit.erase();

      expect(cubit.state.erased, 2);
      await cubit.close();
    });

    test('a failure says so and keeps what was there', () async {
      when(() => store.clear()).thenThrow(const FormatException('bad'));
      final cubit = build();
      await cubit.load();

      await cubit.erase();

      expect(cubit.state.failed, isTrue);
      expect(cubit.state.sizeBytes, 2048);
      expect(cubit.state.erased, 0);
      await cubit.close();
    });

    test('is ignored while something is going on', () async {
      final gate = Completer<void>();
      when(() => store.clear()).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load();

      final first = cubit.erase();
      await cubit.erase();
      gate.complete();
      await first;

      verify(() => store.clear()).called(1);
      await cubit.close();
    });
  });
}
