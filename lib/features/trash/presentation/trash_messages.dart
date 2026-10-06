import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';

/// The text for a failure on the trash screen: the transaction messages, plus
/// the one for a card payment, which cannot be restored.
String trashFailureMessage(Failure failure) {
  if (failure.message.contains('card payment')) {
    return 'Um pagamento de fatura não pode ser restaurado. Pague a fatura de '
        'novo.';
  }
  switch (failure.message) {
    case 'invalid_transfer':
      return 'Transferência inválida.';
    case 'transfer is not deleted':
      return 'Esta transferência já foi restaurada.';
    default:
      return transactionFailureMessage(failure);
  }
}