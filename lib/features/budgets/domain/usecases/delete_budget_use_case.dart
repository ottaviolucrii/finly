import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';

/// Deletes one budget version. Params: the budget id.
class DeleteBudgetUseCase implements UseCase<void, String> {
  final BudgetRepository _repository;

  const DeleteBudgetUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String budgetId) async {
    if (budgetId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_budget'));
    }
    return _repository.deleteBudget(budgetId);
  }
}