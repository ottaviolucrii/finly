import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';

/// The text for a failure when moving a transaction (Portuguese for now;
/// replaced by proper localisation in a later phase). The database says why in
/// English; anything else falls back to the usual transaction messages.
String moveFailureMessage(Failure failure) {
  final message = failure.message;

  if (message.contains('can only go to a bank account')) {
    return 'Uma compra no cartão só pode voltar para uma conta comum.';
  }
  if (message.contains('installment')) {
    return 'Uma compra parcelada não pode mudar de conta.';
  }
  if (message.contains('only an expense')) {
    return 'Só uma despesa pode ir para um cartão.';
  }
  if (message.contains('invoice of that date is already paid')) {
    return 'A fatura da data desta despesa já está paga.';
  }
  if (message.contains('invoice is already paid')) {
    return 'A fatura desta compra já está paga.';
  }
  if (message.contains('card has no details')) {
    return 'O cartão não tem fechamento e vencimento cadastrados.';
  }
  if (message.contains('another currency')) {
    return 'A outra conta usa outra moeda.';
  }
  if (message.contains('archived')) {
    return 'A conta escolhida está arquivada.';
  }
  if (message.contains('another workspace')) {
    return 'A conta escolhida é de outro workspace.';
  }
  if (message.contains('already in this account')) {
    return 'A transação já está nesta conta.';
  }
  if (message.contains('deleted')) {
    return 'Esta transação foi excluída.';
  }
  if (message.contains('transfer legs')) {
    return 'Transferências não podem mudar de conta.';
  }
  if (message == 'invalid_transaction' || message == 'invalid_account') {
    return 'Escolha uma conta válida.';
  }
  return transactionFailureMessage(failure);
}
