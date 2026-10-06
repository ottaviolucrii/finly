import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late GetTransactionsUseCase useCase;

  setUpAll(() => registerFallbackValue(const TransactionFilter()));

  setUp(() {
    repository = MockTransactionRepository();
    useCase = GetTransactionsUseCase(repository);
  });

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.getTransactions(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          filter: any(named: 'filter'),
        ));
  }

  test('rejects an empty workspace id', () async {
    final result = await useCase(const GetTransactionsParams(workspaceId: ' '));

    expect(
      result,
      const Left<Failure, List<TransactionEntity>>(
        ValidationFailure('invalid_workspace'),
      ),
    );
    verifyRepositoryNotCalled();
  });

  test('rejects a page size outside 1-100 and a negative offset', () async {
    const invalid = Left<Failure, List<TransactionEntity>>(
      ValidationFailure('invalid_page'),
    );

    expect(
      await useCase(const GetTransactionsParams(workspaceId: 'w1', limit: 0)),
      invalid,
    );
    expect(
      await useCase(const GetTransactionsParams(workspaceId: 'w1', limit: 101)),
      invalid,
    );
    expect(
      await useCase(const GetTransactionsParams(workspaceId: 'w1', offset: -1)),
      invalid,
    );
    verifyRepositoryNotCalled();
  });

  test('forwards the page and the filter to the repository', () async {
    const filter = TransactionFilter(
      search: 'mercado',
      type: TransactionType.expense,
    );
    when(() => repository.getTransactions(
          'w1',
          limit: 20,
          offset: 40,
          filter: filter,
        )).thenAnswer(
      (_) async => const Right<Failure, List<TransactionEntity>>([]),
    );

    final result = await useCase(
      const GetTransactionsParams(
        workspaceId: 'w1',
        limit: 20,
        offset: 40,
        filter: filter,
      ),
    );

    expect(result.isRight(), isTrue);
    verify(() => repository.getTransactions(
          'w1',
          limit: 20,
          offset: 40,
          filter: filter,
        )).called(1);
  });

  test('uses the first page of 20 and no filter by default', () async {
    when(() => repository.getTransactions(
          'w1',
          limit: 20,
          offset: 0,
          filter: const TransactionFilter(),
        )).thenAnswer(
      (_) async => const Right<Failure, List<TransactionEntity>>([]),
    );

    final result = await useCase(const GetTransactionsParams(workspaceId: 'w1'));

    expect(result.isRight(), isTrue);
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.getTransactions(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          filter: any(named: 'filter'),
        )).thenAnswer(
      (_) async => const Left<Failure, List<TransactionEntity>>(
        NetworkFailure('network_error'),
      ),
    );

    final result = await useCase(const GetTransactionsParams(workspaceId: 'w1'));

    expect(
      result,
      const Left<Failure, List<TransactionEntity>>(
        NetworkFailure('network_error'),
      ),
    );
  });
}