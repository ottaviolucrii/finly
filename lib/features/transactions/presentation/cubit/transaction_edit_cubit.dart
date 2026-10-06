import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/usecases/update_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_edit_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionEditCubit extends Cubit<TransactionEditState> {
  final UpdateTransactionUseCase _updateTransaction;

  TransactionEditCubit(this._updateTransaction)
      : super(const TransactionEditState());

  Future<void> submit({
    required String transactionId,
    String? categoryId,
    required int amountCents,
    required String description,
    required DateTime occurredAt,
    required TransactionStatus status,
  }) async {
    if (state.status == TransactionEditStatus.submitting) return;

    emit(const TransactionEditState(status: TransactionEditStatus.submitting));
    final result = await _updateTransaction(
      UpdateTransactionParams(
        transactionId: transactionId,
        categoryId: categoryId,
        amountCents: amountCents,
        description: description,
        occurredAt: occurredAt,
        status: status,
      ),
    );
    emit(result.fold<TransactionEditState>(
      (failure) => TransactionEditState(
        status: TransactionEditStatus.failure,
        failure: failure,
      ),
      (_) => const TransactionEditState(status: TransactionEditStatus.success),
    ));
  }
}