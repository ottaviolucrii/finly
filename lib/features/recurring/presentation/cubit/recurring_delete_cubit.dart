import 'package:finly/features/recurring/domain/usecases/delete_recurring_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_delete_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecurringDeleteCubit extends Cubit<RecurringDeleteState> {
  final DeleteRecurringUseCase _deleteRecurring;

  RecurringDeleteCubit(this._deleteRecurring)
      : super(const RecurringDeleteState());

  Future<void> delete(String id) async {
    if (state.status == RecurringDeleteStatus.deleting) return;

    emit(const RecurringDeleteState(status: RecurringDeleteStatus.deleting));
    final result = await _deleteRecurring(id);
    emit(result.fold<RecurringDeleteState>(
      (failure) => RecurringDeleteState(
        status: RecurringDeleteStatus.failure,
        failure: failure,
      ),
      (_) => const RecurringDeleteState(status: RecurringDeleteStatus.deleted),
    ));
  }
}