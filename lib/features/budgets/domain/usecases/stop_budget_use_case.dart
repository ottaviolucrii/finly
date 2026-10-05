import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:finly/features/budgets/domain/budget_rules.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';

class StopBudgetParams extends Equatable {
  final String workspaceId;
  final String categoryId;

  /// Any date inside the first month WITHOUT the budget.
  final DateTime month;
  final String currency;

  const StopBudgetParams({
    required this.workspaceId,
    required this.categoryId,
    required this.month,
    required this.currency,
  });

  @override
  List<Object?> get props => [workspaceId, categoryId, month, currency];
}

/// Stops a budget from [StopBudgetParams.month] on by saving an end marker
/// (a version with limit 0). Earlier months keep their budget.
class StopBudgetUseCase implements UseCase<BudgetEntity, StopBudgetParams> {
  final BudgetRepository _repository;

  const StopBudgetUseCase(this._repository);

  @override
  Future<Either<Failure, BudgetEntity>> call(StopBudgetParams params) async {
    if (params.categoryId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_category'));
    }
    if (!CreateAccountUseCase.supportedCurrencies.contains(params.currency)) {
      return const Left(ValidationFailure('invalid_currency'));
    }

    return _repository.saveBudget(
      workspaceId: params.workspaceId,
      categoryId: params.categoryId,
      effectiveFrom: monthStart(params.month),
      limitCents: 0,
      currency: params.currency,
    );
  }
}