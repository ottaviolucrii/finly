import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String transactionFailureMessage(Failure failure) {
  final code = failure.message;

  if (code.contains('category kind')) {
    return 'A categoria não combina com o tipo da transação.';
  }
  if (code.contains('invalid status change')) {
    return 'Esta transação não pode mudar para esse status.';
  }
  if (code.contains('invoice already paid')) {
    return 'A fatura desta compra já foi paga: valor, data e status não podem '
        'mais ser alterados.';
  }
  if (code.contains('transfer legs')) {
    return 'Transferências não podem ser alteradas. Exclua e crie outra.';
  }

  switch (code) {
    case 'invalid_account':
      return 'Escolha uma conta.';
    case 'invalid_amount':
      return 'Informe um valor maior que zero.';
    case 'invalid_description':
      return 'Informe uma descrição (até 200 caracteres).';
    case 'invalid_transaction_type':
    case 'invalid_status':
    case 'invalid_transaction':
      return 'Transação inválida.';
    case 'forbidden':
      return 'Você não tem acesso a este workspace.';
    case 'not_authenticated':
      return 'Sua sessão expirou. Entre novamente.';
    case 'network_error':
      return 'Sem conexão. Verifique sua internet.';
    default:
      return 'Algo deu errado. Tente novamente.';
  }
}