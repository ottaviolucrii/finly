import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/reports/domain/csv_rules.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';

class ExportMonthParams extends Equatable {
  final String workspaceId;

  /// Any day of the month to export.
  final DateTime month;

  const ExportMonthParams({required this.workspaceId, required this.month});

  @override
  List<Object?> get props => [workspaceId, month];
}

/// A file ready to be shared.
class ExportResult extends Equatable {
  final String fileName;
  final String content;
  final int rowCount;

  /// True when the month had more transactions than [ExportMonthUseCase.maxRows]
  /// and the file holds only the most recent ones.
  final bool truncated;

  const ExportResult({
    required this.fileName,
    required this.content,
    required this.rowCount,
    required this.truncated,
  });

  @override
  List<Object?> get props => [fileName, content, rowCount, truncated];
}

/// Every transaction of one month as a CSV file. It reads the same list as the
/// transactions screen, page by page, with the month as the period filter.
class ExportMonthUseCase implements UseCase<ExportResult, ExportMonthParams> {
  static const pageSize = 100;

  /// A safety limit, so a huge month cannot fill the phone's memory.
  static const maxRows = 10000;

  final GetTransactionsUseCase _getTransactions;
  final GetAccountsUseCase _getAccounts;
  final GetAllCategoriesUseCase _getCategories;

  const ExportMonthUseCase(
    this._getTransactions,
    this._getAccounts,
    this._getCategories,
  );

  @override
  Future<Either<Failure, ExportResult>> call(ExportMonthParams params) async {
    final workspaceId = params.workspaceId;
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final month = DateTime(params.month.year, params.month.month);
    final filter = TransactionFilter(
      from: month,
      to: DateTime(month.year, month.month + 1, 0), // the last day
    );

    final rows = <TransactionEntity>[];
    var truncated = false;
    var offset = 0;

    while (true) {
      final page = await _getTransactions(
        GetTransactionsParams(
          workspaceId: workspaceId,
          limit: pageSize,
          offset: offset,
          filter: filter,
        ),
      );

      Failure? failure;
      var items = const <TransactionEntity>[];
      page.fold((f) {
        failure = f;
      }, (value) {
        items = value;
      });
      final problem = failure;
      if (problem != null) return Left<Failure, ExportResult>(problem);

      rows.addAll(items);
      if (items.length < pageSize) break;
      if (rows.length >= maxRows) {
        truncated = true;
        break;
      }
      offset += pageSize;
    }

    if (rows.isEmpty) {
      return const Left(ValidationFailure('nothing_to_export'));
    }

    final (accountsResult, categoriesResult) = await (
      _getAccounts(workspaceId),
      _getCategories(workspaceId),
    ).wait;

    Failure? failure;
    var accounts = const <AccountEntity>[];
    var categories = const <CategoryEntity>[];
    accountsResult.fold((f) {
      failure ??= f;
    }, (value) {
      accounts = value;
    });
    categoriesResult.fold((f) {
      failure ??= f;
    }, (value) {
      categories = value;
    });
    final problem = failure;
    if (problem != null) return Left<Failure, ExportResult>(problem);

    final monthNumber = month.month.toString().padLeft(2, '0');
    return Right<Failure, ExportResult>(
      ExportResult(
        fileName: 'finly-transacoes-${month.year}-$monthNumber.csv',
        content: buildTransactionsCsv(rows, accounts, categories),
        rowCount: rows.length,
        truncated: truncated,
      ),
    );
  }
}