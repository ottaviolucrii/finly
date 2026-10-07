import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/move_rules.dart';
import 'package:finly/features/transactions/domain/usecases/move_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_move_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Moves one transaction to another account. It reads the accounts of the
/// workspace when the edit screen opens, so the list is ready when asked for.
class TransactionMoveCubit extends Cubit<TransactionMoveState> {
  final GetAccountsUseCase _getAccounts;
  final MoveTransactionUseCase _moveTransaction;

  TransactionMoveCubit({
    required GetAccountsUseCase getAccounts,
    required MoveTransactionUseCase moveTransaction,
  })  : _getAccounts = getAccounts,
        _moveTransaction = moveTransaction,
        super(const TransactionMoveState());

  /// Finds the accounts [transaction] can go to. If the accounts cannot be
  /// read, the list is empty and the screen says there is none.
  Future<void> load(TransactionEntity transaction) async {
    final result = await _getAccounts(transaction.workspaceId);
    if (isClosed) return;

    emit(result.fold<TransactionMoveState>(
      (failure) => const TransactionMoveState(status: TransactionMoveStatus.ready),
      (accounts) => TransactionMoveState(
        status: TransactionMoveStatus.ready,
        targets: eligibleMoveTargets(accounts, transaction),
      ),
    ));
  }

  Future<void> move({
    required String transactionId,
    required String accountId,
  }) async {
    if (state.status == TransactionMoveStatus.moving) return;

    emit(TransactionMoveState(
      status: TransactionMoveStatus.moving,
      targets: state.targets,
    ));

    final result = await _moveTransaction(
      MoveTransactionParams(transactionId: transactionId, accountId: accountId),
    );
    if (isClosed) return;

    emit(result.fold<TransactionMoveState>(
      (failure) => TransactionMoveState(
        status: TransactionMoveStatus.failure,
        targets: state.targets,
        failure: failure,
      ),
      (_) => TransactionMoveState(
        status: TransactionMoveStatus.moved,
        targets: state.targets,
      ),
    ));
  }
}
