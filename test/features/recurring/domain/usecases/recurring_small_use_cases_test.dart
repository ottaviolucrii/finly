import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finly/features/recurring/domain/usecases/generate_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/get_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/set_recurring_active_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

void main() {
  late MockRecurringRepository repository;

  setUp(() => repository = MockRecurringRepository());

  group('GetRecurringUseCase', () {
    test('rejects an empty workspace id', () async {
      final result = await GetRecurringUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, List<RecurringEntity>>(
          ValidationFailure('invalid_workspace'),
        ),
      );
      verifyNever(() => repository.getRecurring(any()));
    });

    test('returns the items of the workspace', () async {
      when(() => repository.getRecurring('w1')).thenAnswer(
        (_) async => const Right<Failure, List<RecurringEntity>>([]),
      );

      final result = await GetRecurringUseCase(repository)('w1');

      expect(result.isRight(), isTrue);
      verify(() => repository.getRecurring('w1')).called(1);
    });
  });

  group('SetRecurringActiveUseCase', () {
    test('rejects an empty id', () async {
      final result = await SetRecurringActiveUseCase(repository)(
        const SetRecurringActiveParams(id: ' ', active: false),
      );

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('invalid_recurring')),
      );
      verifyNever(() => repository.setActive(any(), active: any(named: 'active')));
    });

    test('pauses and resumes', () async {
      when(() => repository.setActive('r1', active: false))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      when(() => repository.setActive('r1', active: true))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      final useCase = SetRecurringActiveUseCase(repository);

      final paused = await useCase(
        const SetRecurringActiveParams(id: 'r1', active: false),
      );
      final resumed = await useCase(
        const SetRecurringActiveParams(id: 'r1', active: true),
      );

      expect(paused.isRight(), isTrue);
      expect(resumed.isRight(), isTrue);
    });
  });

  group('GenerateRecurringUseCase', () {
    test('asks the repository to create what is due', () async {
      when(() => repository.generateDue())
          .thenAnswer((_) async => const Right<Failure, int>(3));

      final result = await GenerateRecurringUseCase(repository)(const NoParams());

      expect(result, const Right<Failure, int>(3));
    });
  });
}