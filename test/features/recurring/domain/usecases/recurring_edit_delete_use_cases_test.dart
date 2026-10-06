import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finly/features/recurring/domain/usecases/delete_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/update_recurring_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

void main() {
  late MockRecurringRepository repository;

  final start = DateTime(2026, 10, 5);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repository = MockRecurringRepository());

  group('UpdateRecurringUseCase', () {
    UpdateRecurringParams params({
      String id = 'r1',
      String? categoryId = 'c1',
      int amountCents = 130000,
      String description = 'Aluguel',
      DateTime? endDate,
    }) {
      return UpdateRecurringParams(
        id: id,
        categoryId: categoryId,
        amountCents: amountCents,
        description: description,
        startDate: start,
        endDate: endDate,
      );
    }

    void verifyNotCalled() {
      verifyNever(() => repository.updateRecurring(
            id: any(named: 'id'),
            categoryId: any(named: 'categoryId'),
            amountCents: any(named: 'amountCents'),
            description: any(named: 'description'),
            endDate: any(named: 'endDate'),
          ));
    }

    Future<void> expectRejected(UpdateRecurringParams p, String code) async {
      final result = await UpdateRecurringUseCase(repository)(p);
      expect(result, Left<Failure, void>(ValidationFailure(code)));
      verifyNotCalled();
    }

    test('rejects a missing id', () async {
      await expectRejected(params(id: ' '), 'invalid_recurring');
    });

    test('rejects a zero or negative amount', () async {
      await expectRejected(params(amountCents: 0), 'invalid_amount');
      await expectRejected(params(amountCents: -1), 'invalid_amount');
    });

    test('rejects an empty or too long description', () async {
      await expectRejected(params(description: '  '), 'invalid_description');
      await expectRejected(params(description: 'a' * 201), 'invalid_description');
    });

    test('rejects an end date before the start date', () async {
      await expectRejected(
        params(endDate: DateTime(2026, 10, 4)),
        'invalid_end_date',
      );
    });

    test('accepts an end date equal to the start date', () async {
      when(() => repository.updateRecurring(
            id: 'r1',
            categoryId: 'c1',
            amountCents: 130000,
            description: 'Aluguel',
            endDate: start,
          )).thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await UpdateRecurringUseCase(repository)(
        params(endDate: start),
      );

      expect(result.isRight(), isTrue);
    });

    test('trims the description and forwards to the repository', () async {
      when(() => repository.updateRecurring(
            id: 'r1',
            categoryId: null,
            amountCents: 130000,
            description: 'Aluguel',
            endDate: null,
          )).thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await UpdateRecurringUseCase(repository)(
        params(categoryId: null, description: '  Aluguel '),
      );

      expect(result.isRight(), isTrue);
    });

    test('passes a repository failure through unchanged', () async {
      when(() => repository.updateRecurring(
            id: any(named: 'id'),
            categoryId: any(named: 'categoryId'),
            amountCents: any(named: 'amountCents'),
            description: any(named: 'description'),
            endDate: any(named: 'endDate'),
          )).thenAnswer(
        (_) async => const Left<Failure, void>(PermissionFailure('forbidden')),
      );

      final result = await UpdateRecurringUseCase(repository)(params());

      expect(
        result,
        const Left<Failure, void>(PermissionFailure('forbidden')),
      );
    });
  });

  group('DeleteRecurringUseCase', () {
    test('rejects an empty id', () async {
      final result = await DeleteRecurringUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('invalid_recurring')),
      );
      verifyNever(() => repository.deleteRecurring(any()));
    });

    test('forwards the id to the repository', () async {
      when(() => repository.deleteRecurring('r1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await DeleteRecurringUseCase(repository)('r1');

      expect(result.isRight(), isTrue);
      verify(() => repository.deleteRecurring('r1')).called(1);
    });
  });
}