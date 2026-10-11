import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/usecases/confirm_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_cubit.dart';
import 'package:finly/features/transactions/presentation/statement_filters.dart';
import 'package:finly/features/transfers/domain/usecases/delete_transfer_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetTransactions extends Mock implements GetTransactionsUseCase {}

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockGetCategories extends Mock implements GetAllCategoriesUseCase {}

class MockConfirm extends Mock implements ConfirmTransactionUseCase {}

class MockDelete extends Mock implements DeleteTransactionUseCase {}

class MockRestore extends Mock implements RestoreTransactionUseCase {}

class MockDeleteTransfer extends Mock implements DeleteTransferUseCase {}

void main() {
  late MockGetTransactions getTransactions;
  late MockGetAccounts getAccounts;
  late MockGetCategories getCategories;

  final october = filterForMonth(const TransactionFilter(), DateTime(2026, 10, 10));

  setUpAll(() => registerFallbackValue(
        const GetTransactionsParams(workspaceId: 'w1', limit: TransactionsCubit.pageSize),
      ));

  setUp(() {
    getTransactions = MockGetTransactions();
    getAccounts = MockGetAccounts();
    getCategories = MockGetCategories();
    when(() => getAccounts('w1')).thenAnswer((_) async => const Right<Failure, List<AccountEntity>>([]));
    when(() => getCategories('w1')).thenAnswer((_) async => const Right<Failure, List<CategoryEntity>>([]));
    when(() => getTransactions(any())).thenAnswer((_) async => const Right<Failure, List<TransactionEntity>>([]));
  });

  TransactionsCubit build() => TransactionsCubit(
        getTransactions: getTransactions,
        getAccounts: getAccounts,
        getCategories: getCategories,
        confirmTransaction: MockConfirm(),
        deleteTransaction: MockDelete(),
        restoreTransaction: MockRestore(),
        deleteTransfer: MockDeleteTransfer(),
      );

  test('load can start with a filter, in one read', () async {
    final cubit = build();

    await cubit.load('w1', filter: october);

    expect(cubit.state.filter, october);
    final asked = verify(() => getTransactions(captureAny())).captured;
    expect(asked, hasLength(1));
    expect((asked.single as GetTransactionsParams).filter, october);
    await cubit.close();
  });

  test('load without a filter keeps the current one', () async {
    final cubit = build();

    await cubit.load('w1', filter: october);
    await cubit.load('w1');

    expect(cubit.state.filter, october);
    await cubit.close();
  });
}
