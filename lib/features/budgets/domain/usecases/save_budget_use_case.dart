import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:finly/features/budgets/domain/budget_rules.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';

class SaveBudgetParams extends Equatable {
  final String workspaceId;
  final String categoryId;

  /// Any date inside the month the limit starts to apply.
  final DateTime month;
  final int limitCents;
  final String currency;

  const SaveBudgetParams({
    required this.workspaceId,
    required this.categoryId,
    required this.month,
    required this.limitCents,
    required this.currency,
  });

  @override
  List<Object?> get props =>
      [workspaceId, categoryId, month, limitCents, currency];
}

class SaveBudgetUseCase implements UseCase<BudgetEntity, SaveBudgetParams> {
  final BudgetRepository _repository;

  const SaveBudgetUseCase(this._repository);

  @override
  Future<Either<Failure, BudgetEntity>> call(SaveBudgetParams params) async {
    if (params.categoryId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_category'));
    }
    if (params.limitCents <= 0) {
      return const Left(ValidationFailure('invalid_limit'));
    }
    if (!CreateAccountUseCase.supportedCurrencies.contains(params.currency)) {
      return const Left(ValidationFailure('invalid_currency'));
    }

    return _repository.saveBudget(
      workspaceId: params.workspaceId,
      categoryId: params.categoryId,
      effectiveFrom: monthStart(params.month),
      limitCents: params.limitCents,
      currency: params.currency,
    );
  }
}