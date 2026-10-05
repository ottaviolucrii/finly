import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionFormCubit extends Cubit<TransactionFormState> {
  final CreateTransactionUseCase _createTransaction;

  TransactionFormCubit(this._createTransaction)
      : super(const TransactionFormState());

  Future<void> submit({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required TransactionStatus status,
    required int amountCents,
    required String currency,
    required String description,
    required DateTime occurredAt,
  }) async {
    if (state.status == TransactionFormStatus.submitting) return;

    emit(const TransactionFormState(status: TransactionFormStatus.submitting));
    final result = await _createTransaction(
      CreateTransactionParams(
        workspaceId: workspaceId,
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        status: status,
        amountCents: amountCents,
        currency: currency,
        description: description,
        occurredAt: occurredAt,
      ),
    );
    emit(result.fold<TransactionFormState>(
      (failure) => TransactionFormState(
        status: TransactionFormStatus.failure,
        failure: failure,
      ),
      (transaction) => TransactionFormState(
        status: TransactionFormStatus.success,
        transaction: transaction,
      ),
    ));
  }
}