import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/domain/usecases/get_appearance_use_case.dart';
import 'package:finly/features/appearance/domain/usecases/save_appearance_use_case.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_cubit.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGet extends Mock implements GetAppearanceUseCase {}

class MockSave extends Mock implements SaveAppearanceUseCase {}

void main() {
  late MockGet getAppearance;
  late MockSave saveAppearance;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(AppearanceMode.system);
  });

  setUp(() {
    getAppearance = MockGet();
    saveAppearance = MockSave();
    when(() => saveAppearance(any()))
        .thenAnswer((_) async => const Right<Failure, void>(null));
  });

  AppearanceCubit build() =>
      AppearanceCubit(getAppearance: getAppearance, saveAppearance: saveAppearance);

  blocTest<AppearanceCubit, AppearanceState>(
    'starts following the phone',
    build: build,
    verify: (cubit) {
      expect(cubit.state.mode, AppearanceMode.system);
      expect(cubit.state.loaded, isFalse);
    },
  );

  blocTest<AppearanceCubit, AppearanceState>(
    'load applies the saved choice',
    build: () {
      when(() => getAppearance(any())).thenAnswer(
        (_) async => const Right<Failure, AppearanceMode>(AppearanceMode.dark),
      );
      return build();
    },
    act: (cubit) => cubit.load(),
    expect: () => [const AppearanceState(mode: AppearanceMode.dark, loaded: true)],
  );

  blocTest<AppearanceCubit, AppearanceState>(
    'load keeps following the phone when the choice cannot be read',
    build: () {
      when(() => getAppearance(any())).thenAnswer(
        (_) async => const Left<Failure, AppearanceMode>(NetworkFailure('network_error')),
      );
      return build();
    },
    act: (cubit) => cubit.load(),
    expect: () => <AppearanceState>[],
  );

  blocTest<AppearanceCubit, AppearanceState>(
    'setMode changes the theme at once and saves it',
    build: build,
    act: (cubit) => cubit.setMode(AppearanceMode.light),
    expect: () => [const AppearanceState(mode: AppearanceMode.light)],
    verify: (_) => verify(() => saveAppearance(AppearanceMode.light)).called(1),
  );

  blocTest<AppearanceCubit, AppearanceState>(
    'setMode to the same choice does nothing',
    build: build,
    act: (cubit) => cubit.setMode(AppearanceMode.system),
    expect: () => <AppearanceState>[],
    verify: (_) => verifyNever(() => saveAppearance(any())),
  );

  blocTest<AppearanceCubit, AppearanceState>(
    'a failed save puts the theme back and says so',
    build: () {
      when(() => saveAppearance(any())).thenAnswer(
        (_) async => const Left<Failure, void>(NetworkFailure('network_error')),
      );
      return build();
    },
    act: (cubit) => cubit.setMode(AppearanceMode.dark),
    expect: () => [
      const AppearanceState(mode: AppearanceMode.dark),
      const AppearanceState(error: AppearanceError.saveFailed),
    ],
  );

  blocTest<AppearanceCubit, AppearanceState>(
    'a new change clears the old error',
    build: build,
    seed: () => const AppearanceState(error: AppearanceError.saveFailed),
    act: (cubit) => cubit.setMode(AppearanceMode.light),
    expect: () => [const AppearanceState(mode: AppearanceMode.light)],
  );

  blocTest<AppearanceCubit, AppearanceState>(
    'reset goes back to following the phone',
    build: build,
    seed: () => const AppearanceState(mode: AppearanceMode.dark, loaded: true),
    act: (cubit) => cubit.reset(),
    expect: () => [const AppearanceState()],
  );
}
