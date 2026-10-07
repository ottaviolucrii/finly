import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';

abstract class TransactionMoveRepository {
  /// Moves an income or an expense to another account of its workspace. The
  /// database refuses a card purchase, a transfer leg, a deleted transaction,
  /// another currency, an archived account and a credit card.
  Future<Either<Failure, void>> moveTransaction(
    String transactionId,
    String accountId,
  );
}
