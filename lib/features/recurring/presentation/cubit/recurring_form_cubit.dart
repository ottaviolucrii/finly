import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/usecases/create_recurring_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_form_state.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecurringFormCubit extends Cubit<RecurringFormState> {
  final CreateRecurringUseCase _createRecurring;

  RecurringFormCubit(this._createRecurring) : super(const RecurringFormState());

  Future<void> submit({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required int amountCents,
    required String currency,
    required String description,
    required RecurrenceFrequency frequency,
    required int intervalCount,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (state.status == RecurringFormStatus.submitting) return;

    emit(const RecurringFormState(status: RecurringFormStatus.submitting));
    final result = await _createRecurring(
      CreateRecurringParams(
        workspaceId: workspaceId,
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        amountCents: amountCents,
        currency: currency,
        description: description,
        frequency: frequency,
        intervalCount: intervalCount,
        startDate: startDate,
        endDate: endDate,
      ),
    );
    emit(result.fold<RecurringFormState>(
      (failure) => RecurringFormState(
        status: RecurringFormStatus.failure,
        failure: failure,
      ),
      (_) => const RecurringFormState(status: RecurringFormStatus.success),
    ));
  }
}