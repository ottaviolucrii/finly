import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finly/features/transactions/domain/usecases/update_transaction_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late UpdateTransactionUseCase useCase;

  final occurredAt = DateTime(2026, 10, 2, 12);
  final updated = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: 'c1',
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 3000,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: occurredAt,
  );

  setUpAll(() {
    registerFallbackValue(TransactionStatus.posted);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repository = MockTransactionRepository();
    useCase = UpdateTransactionUseCase(repository);
  });

  UpdateTransactionParams params({
    String transactionId = 't1',
    String? categoryId = 'c1',
    int amountCents = 3000,
    String description = 'Mercado',
    TransactionStatus status = TransactionStatus.posted,
  }) {
    return UpdateTransactionParams(
      transactionId: transactionId,
      categoryId: categoryId,
      amountCents: amountCents,
      description: description,
      occurredAt: occurredAt,
      status: status,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.updateTransaction(
          transactionId: any(named: 'transactionId'),
          categoryId: any(named: 'categoryId'),
          amountCents: any(named: 'amountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          status: any(named: 'status'),
        ));
  }

  Future<void> expectRejected(UpdateTransactionParams p, String code) async {
    final result = await useCase(p);
    expect(result, Left<Failure, TransactionEntity>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects a missing transaction id', () async {
    await expectRejected(params(transactionId: ' '), 'invalid_transaction');
  });

  test('rejects setting the status to failed', () async {
    await expectRejected(
      params(status: TransactionStatus.failed),
      'invalid_status',
    );
  });

  test('rejects a zero or negative amount', () async {
    await expectRejected(params(amountCents: 0), 'invalid_amount');
    await expectRejected(params(amountCents: -5), 'invalid_amount');
  });

  test('rejects an empty or too long description', () async {
    await expectRejected(params(description: '  '), 'invalid_description');
    await expectRejected(params(description: 'a' * 201), 'invalid_description');
  });

  test('trims the description and forwards to the repository', () async {
    when(() => repository.updateTransaction(
          transactionId: 't1',
          categoryId: 'c1',
          amountCents: 3000,
          description: 'Mercado',
          occurredAt: occurredAt,
          status: TransactionStatus.posted,
        )).thenAnswer((_) async => Right<Failure, TransactionEntity>(updated));

    final result = await useCase(params(description: '  Mercado '));

    expect(result, Right<Failure, TransactionEntity>(updated));
  });

  test('a null category clears the category', () async {
    when(() => repository.updateTransaction(
          transactionId: 't1',
          categoryId: null,
          amountCents: 3000,
          description: 'Mercado',
          occurredAt: occurredAt,
          status: TransactionStatus.posted,
        )).thenAnswer((_) async => Right<Failure, TransactionEntity>(updated));

    final result = await useCase(params(categoryId: null));

    expect(result.isRight(), isTrue);
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.updateTransaction(
          transactionId: any(named: 'transactionId'),
          categoryId: any(named: 'categoryId'),
          amountCents: any(named: 'amountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          status: any(named: 'status'),
        )).thenAnswer(
      (_) async => const Left<Failure, TransactionEntity>(
        RuleFailure('invoice already paid: its transactions are locked'),
      ),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, TransactionEntity>(
        RuleFailure('invoice already paid: its transactions are locked'),
      ),
    );
  });
}