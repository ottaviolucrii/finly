import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/data/datasources/budget_remote_data_source.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/category_spend.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetRemoteDataSource _remote;

  const BudgetRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<BudgetEntity>>> getBudgets(String workspaceId) {
    return _guard<List<BudgetEntity>>(() => _remote.getBudgets(workspaceId));
  }

  @override
  Future<Either<Failure, List<CategorySpend>>> getMonthlySpend(
    String workspaceId,
    DateTime month,
  ) {
    return _guard<List<CategorySpend>>(
      () => _remote.getMonthlySpend(workspaceId, month),
    );
  }

  @override
  Future<Either<Failure, BudgetEntity>> saveBudget({
    required String workspaceId,
    required String categoryId,
    required DateTime effectiveFrom,
    required int limitCents,
    required String currency,
  }) {
    return _guard<BudgetEntity>(
      () => _remote.saveBudget(
        workspaceId: workspaceId,
        categoryId: categoryId,
        effectiveFrom: effectiveFrom,
        limitCents: limitCents,
        currency: currency,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> deleteBudget(String budgetId) {
    return _guard<void>(() => _remote.deleteBudget(budgetId));
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error, not Exception) are not caught on purpose.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } on Exception catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}