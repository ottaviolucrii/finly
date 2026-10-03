import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finly/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late CreateTransactionUseCase useCase;

  final occurredAt = DateTime(2026, 10, 2, 12);
  final transaction = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: 'c1',
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 2500,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: occurredAt,
  );

  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(TransactionStatus.posted);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repository = MockTransactionRepository();
    useCase = CreateTransactionUseCase(repository);
  });

  CreateTransactionParams params({
    String accountId = 'a1',
    TransactionType type = TransactionType.expense,
    TransactionStatus status = TransactionStatus.posted,
    int amountCents = 2500,
    String description = 'Mercado',
  }) {
    return CreateTransactionParams(
      workspaceId: 'w1',
      accountId: accountId,
      categoryId: 'c1',
      type: type,
      status: status,
      amountCents: amountCents,
      currency: 'BRL',
      description: description,
      occurredAt: occurredAt,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.createTransaction(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          status: any(named: 'status'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
        ));
  }

  Future<void> expectRejected(CreateTransactionParams p, String code) async {
    final result = await useCase(p);
    expect(result, Left<Failure, TransactionEntity>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects a missing account', () async {
    await expectRejected(params(accountId: ' '), 'invalid_account');
  });

  test('rejects transfers (they have their own flow)', () async {
    await expectRejected(
      params(type: TransactionType.transferOut),
      'invalid_transaction_type',
    );
  });

  test('rejects a new transaction that is already failed', () async {
    await expectRejected(
      params(status: TransactionStatus.failed),
      'invalid_status',
    );
  });

  test('rejects a zero amount', () async {
    await expectRejected(params(amountCents: 0), 'invalid_amount');
  });

  test('rejects a negative amount (the type gives the direction)', () async {
    await expectRejected(params(amountCents: -100), 'invalid_amount');
  });

  test('rejects an empty description', () async {
    await expectRejected(params(description: '   '), 'invalid_description');
  });

  test('rejects a description longer than 200 characters', () async {
    await expectRejected(
      params(description: 'a' * 201),
      'invalid_description',
    );
  });

  test('trims the description and forwards to the repository', () async {
    when(() => repository.createTransaction(
          workspaceId: 'w1',
          accountId: 'a1',
          categoryId: 'c1',
          type: TransactionType.expense,
          status: TransactionStatus.posted,
          amountCents: 2500,
          currency: 'BRL',
          description: 'Mercado',
          occurredAt: occurredAt,
        )).thenAnswer(
      (_) async => Right<Failure, TransactionEntity>(transaction),
    );

    final result = await useCase(params(description: '  Mercado '));

    expect(result, Right<Failure, TransactionEntity>(transaction));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.createTransaction(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          status: any(named: 'status'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
        )).thenAnswer(
      (_) async => const Left<Failure, TransactionEntity>(
        PermissionFailure('forbidden'),
      ),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, TransactionEntity>(PermissionFailure('forbidden')),
    );
  });
}