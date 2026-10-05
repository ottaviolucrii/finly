import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finly/features/recurring/domain/usecases/create_recurring_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

void main() {
  late MockRecurringRepository repository;
  late CreateRecurringUseCase useCase;

  final start = DateTime(2026, 3, 5);
  final created = RecurringEntity(
    id: 'r1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: null,
    type: TransactionType.expense,
    amountCents: 120000,
    currency: 'BRL',
    description: 'Aluguel',
    frequency: RecurrenceFrequency.monthly,
    intervalCount: 1,
    startDate: start,
    endDate: null,
    isActive: true,
  );

  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(RecurrenceFrequency.monthly);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repository = MockRecurringRepository();
    useCase = CreateRecurringUseCase(repository);
  });

  CreateRecurringParams params({
    String accountId = 'a1',
    TransactionType type = TransactionType.expense,
    int amountCents = 120000,
    String description = 'Aluguel',
    int intervalCount = 1,
    DateTime? endDate,
  }) {
    return CreateRecurringParams(
      workspaceId: 'w1',
      accountId: accountId,
      type: type,
      amountCents: amountCents,
      currency: 'BRL',
      description: description,
      frequency: RecurrenceFrequency.monthly,
      intervalCount: intervalCount,
      startDate: start,
      endDate: endDate,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.createRecurring(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          frequency: any(named: 'frequency'),
          intervalCount: any(named: 'intervalCount'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ));
  }

  Future<void> expectRejected(CreateRecurringParams p, String code) async {
    final result = await useCase(p);
    expect(result, Left<Failure, RecurringEntity>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects a missing account', () async {
    await expectRejected(params(accountId: ' '), 'invalid_account');
  });

  test('rejects transfers', () async {
    await expectRejected(
      params(type: TransactionType.transferOut),
      'invalid_transaction_type',
    );
  });

  test('rejects a zero or negative amount', () async {
    await expectRejected(params(amountCents: 0), 'invalid_amount');
    await expectRejected(params(amountCents: -10), 'invalid_amount');
  });

  test('rejects an empty or too long description', () async {
    await expectRejected(params(description: '  '), 'invalid_description');
    await expectRejected(
      params(description: 'a' * 201),
      'invalid_description',
    );
  });

  test('rejects an interval outside 1-52', () async {
    await expectRejected(params(intervalCount: 0), 'invalid_interval');
    await expectRejected(params(intervalCount: 53), 'invalid_interval');
  });

  test('rejects an end date before the start', () async {
    await expectRejected(
      params(endDate: DateTime(2026, 3, 4)),
      'invalid_end_date',
    );
  });

  test('accepts an end date equal to the start', () async {
    when(() => repository.createRecurring(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          frequency: any(named: 'frequency'),
          intervalCount: any(named: 'intervalCount'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => Right<Failure, RecurringEntity>(created));

    final result = await useCase(params(endDate: start));

    expect(result.isRight(), isTrue);
  });

  test('trims the description and forwards to the repository', () async {
    when(() => repository.createRecurring(
          workspaceId: 'w1',
          accountId: 'a1',
          categoryId: null,
          type: TransactionType.expense,
          amountCents: 120000,
          currency: 'BRL',
          description: 'Aluguel',
          frequency: RecurrenceFrequency.monthly,
          intervalCount: 1,
          startDate: start,
          endDate: null,
        )).thenAnswer((_) async => Right<Failure, RecurringEntity>(created));

    final result = await useCase(params(description: '  Aluguel '));

    expect(result, Right<Failure, RecurringEntity>(created));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.createRecurring(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          frequency: any(named: 'frequency'),
          intervalCount: any(named: 'intervalCount'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer(
      (_) async => const Left<Failure, RecurringEntity>(
        PermissionFailure('forbidden'),
      ),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, RecurringEntity>(PermissionFailure('forbidden')),
    );
  });
}