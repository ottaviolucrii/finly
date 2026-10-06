import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/reports/domain/usecases/export_month_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetTransactions extends Mock implements GetTransactionsUseCase {}

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockGetCategories extends Mock implements GetAllCategoriesUseCase {}

void main() {
  late MockGetTransactions getTransactions;
  late MockGetAccounts getAccounts;
  late MockGetCategories getCategories;
  late ExportMonthUseCase useCase;

  final october = DateTime(2026, 10, 15, 9);
  final filter = TransactionFilter(
    from: DateTime(2026, 10, 1),
    to: DateTime(2026, 10, 31),
  );

  const account = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: 0,
    projectedBalanceCents: 0,
  );

  List<TransactionEntity> rows(int from, int count) => [
        for (var i = from; i < from + count; i++)
          TransactionEntity(
            id: 't$i',
            workspaceId: 'w1',
            accountId: 'a1',
            categoryId: null,
            type: TransactionType.expense,
            status: TransactionStatus.posted,
            amountCents: 1000,
            currency: 'BRL',
            description: 'Item $i',
            occurredAt: DateTime(2026, 10, 5, 12),
          ),
      ];

  GetTransactionsParams page(int offset) => GetTransactionsParams(
        workspaceId: 'w1',
        limit: ExportMonthUseCase.pageSize,
        offset: offset,
        filter: filter,
      );

  void stubPage(int offset, List<TransactionEntity> list) {
    when(() => getTransactions(page(offset))).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>(list),
    );
  }

  ExportMonthParams params() =>
      ExportMonthParams(workspaceId: 'w1', month: october);

  setUpAll(() => registerFallbackValue(page(0)));

  setUp(() {
    getTransactions = MockGetTransactions();
    getAccounts = MockGetAccounts();
    getCategories = MockGetCategories();
    useCase = ExportMonthUseCase(getTransactions, getAccounts, getCategories);

    when(() => getAccounts('w1')).thenAnswer(
      (_) async => const Right<Failure, List<AccountEntity>>([account]),
    );
    when(() => getCategories('w1')).thenAnswer(
      (_) async => const Right<Failure, List<CategoryEntity>>([]),
    );
  });

  test('rejects an empty workspace id', () async {
    final result = await useCase(
      ExportMonthParams(workspaceId: ' ', month: october),
    );

    expect(
      result,
      const Left<Failure, ExportResult>(ValidationFailure('invalid_workspace')),
    );
  });

  test('asks for the whole month as the period', () async {
    stubPage(0, rows(1, 3));

    await useCase(params());

    verify(() => getTransactions(page(0))).called(1);
  });

  test('builds the file of a short month in one page', () async {
    stubPage(0, rows(1, 3));

    final result = await useCase(params());

    result.fold(
      (failure) => fail('expected a file, got $failure'),
      (file) {
        expect(file.fileName, 'finly-transacoes-2026-10.csv');
        expect(file.rowCount, 3);
        expect(file.truncated, isFalse);
        expect(file.content, contains('Item 1'));
        expect(file.content, contains('Nubank'));
      },
    );
  });

  test('reads a second page when the first one is full', () async {
    stubPage(0, rows(1, 100));
    stubPage(100, rows(101, 5));

    final result = await useCase(params());

    result.fold(
      (failure) => fail('expected a file, got $failure'),
      (file) {
        expect(file.rowCount, 105);
        expect(file.truncated, isFalse);
      },
    );
    verify(() => getTransactions(page(100))).called(1);
  });

  test('stops at the safety limit and says the file is partial', () async {
    when(() => getTransactions(any())).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>(rows(1, 100)),
    );

    final result = await useCase(params());

    result.fold(
      (failure) => fail('expected a file, got $failure'),
      (file) {
        expect(file.rowCount, ExportMonthUseCase.maxRows);
        expect(file.truncated, isTrue);
      },
    );
  });

  test('a month with nothing is refused instead of sharing an empty file', () async {
    stubPage(0, const []);

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, ExportResult>(ValidationFailure('nothing_to_export')),
    );
  });

  test('passes a failure while reading a page through unchanged', () async {
    when(() => getTransactions(any())).thenAnswer(
      (_) async => const Left<Failure, List<TransactionEntity>>(
        NetworkFailure('network_error'),
      ),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, ExportResult>(NetworkFailure('network_error')),
    );
  });

  test('passes a failure loading the accounts through unchanged', () async {
    stubPage(0, rows(1, 2));
    when(() => getAccounts('w1')).thenAnswer(
      (_) async => const Left<Failure, List<AccountEntity>>(
        NetworkFailure('network_error'),
      ),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, ExportResult>(NetworkFailure('network_error')),
    );
  });
}