import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/domain/repositories/appearance_repository.dart';
import 'package:finly/features/appearance/domain/usecases/get_appearance_use_case.dart';
import 'package:finly/features/appearance/domain/usecases/save_appearance_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements AppearanceRepository {}

void main() {
  late MockRepository repository;

  setUpAll(() => registerFallbackValue(AppearanceMode.system));

  setUp(() => repository = MockRepository());

  group('GetAppearanceUseCase', () {
    test('returns the saved choice', () async {
      when(() => repository.getMode()).thenAnswer(
        (_) async => const Right<Failure, AppearanceMode>(AppearanceMode.dark),
      );

      final result = await GetAppearanceUseCase(repository)(const NoParams());

      expect(result, const Right<Failure, AppearanceMode>(AppearanceMode.dark));
    });

    test('passes a failure through unchanged', () async {
      when(() => repository.getMode()).thenAnswer(
        (_) async => const Left<Failure, AppearanceMode>(NetworkFailure('network_error')),
      );

      final result = await GetAppearanceUseCase(repository)(const NoParams());

      expect(result, const Left<Failure, AppearanceMode>(NetworkFailure('network_error')));
    });
  });

  group('SaveAppearanceUseCase', () {
    test('forwards the choice to the repository', () async {
      when(() => repository.saveMode(AppearanceMode.light))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await SaveAppearanceUseCase(repository)(AppearanceMode.light);

      expect(result.isRight(), isTrue);
      verify(() => repository.saveMode(AppearanceMode.light)).called(1);
    });

    test('passes a failure through unchanged', () async {
      when(() => repository.saveMode(any())).thenAnswer(
        (_) async => const Left<Failure, void>(PermissionFailure('forbidden')),
      );

      final result = await SaveAppearanceUseCase(repository)(AppearanceMode.dark);

      expect(result, const Left<Failure, void>(PermissionFailure('forbidden')));
    });
  });
}
