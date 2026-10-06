import 'package:finly/features/recurring/domain/usecases/update_recurring_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_edit_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecurringEditCubit extends Cubit<RecurringEditState> {
  final UpdateRecurringUseCase _updateRecurring;

  RecurringEditCubit(this._updateRecurring) : super(const RecurringEditState());

  Future<void> submit({
    required String id,
    String? categoryId,
    required int amountCents,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (state.status == RecurringEditStatus.submitting) return;

    emit(const RecurringEditState(status: RecurringEditStatus.submitting));
    final result = await _updateRecurring(
      UpdateRecurringParams(
        id: id,
        categoryId: categoryId,
        amountCents: amountCents,
        description: description,
        startDate: startDate,
        endDate: endDate,
      ),
    );
    emit(result.fold<RecurringEditState>(
      (failure) => RecurringEditState(
        status: RecurringEditStatus.failure,
        failure: failure,
      ),
      (_) => const RecurringEditState(status: RecurringEditStatus.success),
    ));
  }
} 