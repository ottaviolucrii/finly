import 'package:finly/features/budgets/domain/usecases/save_budget_use_case.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BudgetFormCubit extends Cubit<BudgetFormState> {
  final SaveBudgetUseCase _saveBudget;

  BudgetFormCubit(this._saveBudget) : super(const BudgetFormState());

  Future<void> submit({
    required String workspaceId,
    required String categoryId,
    required DateTime month,
    required int limitCents,
    required String currency,
  }) async {
    if (state.status == BudgetFormStatus.submitting) return;

    emit(const BudgetFormState(status: BudgetFormStatus.submitting));
    final result = await _saveBudget(
      SaveBudgetParams(
        workspaceId: workspaceId,
        categoryId: categoryId,
        month: month,
        limitCents: limitCents,
        currency: currency,
      ),
    );
    emit(result.fold<BudgetFormState>(
      (failure) =>
          BudgetFormState(status: BudgetFormStatus.failure, failure: failure),
      (_) => const BudgetFormState(status: BudgetFormStatus.success),
    ));
  }
}