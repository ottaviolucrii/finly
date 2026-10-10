import 'package:finly/core/error/failure.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/cards/domain/payment_amount.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String cardFailureMessage(Failure failure) {
  final code = failure.message;

  if (code.contains('invoice already paid')) {
    return 'Esta fatura já foi paga.';
  }
  if (code.contains('nothing to pay')) {
    return 'Esta fatura não tem nada a pagar.';
  }
  if (code.contains('above what is owed')) {
    return 'O valor é maior do que falta pagar.';
  }
  if (code.contains('amount must be positive')) {
    return 'Informe um valor maior que zero.';
  }
  if (code.contains('amounts must match') ||
      code.contains('destination amount')) {
    return 'A conta de pagamento deve usar a mesma moeda do cartão.';
  }

  switch (code) {
    case 'invalid_account_name':
      return 'Informe um nome para o cartão (até 80 caracteres).';
    case 'invalid_currency':
      return 'Moeda não suportada.';
    case 'invalid_limit':
      return 'Informe um limite maior que zero.';
    case 'invalid_day':
      return 'Os dias de fechamento e de vencimento vão de 1 a 31.';
    case 'invalid_installments':
      return 'O número de parcelas vai de 2 a 48.';
    case 'invalid_amount':
      return 'Informe um valor válido para a compra.';
    case 'invalid_payment_amount':
      return 'Informe um valor maior que zero.';
    case 'invalid_description':
      return 'Informe uma descrição (até 200 caracteres).';
    case 'already_exists':
      return 'Já existe uma conta com esse nome neste workspace.';
    case 'invalid_workspace':
    case 'invalid_account':
    case 'invalid_invoice':
      return 'Cartão ou fatura inválidos.';
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

/// What is wrong with the amount typed to pay an invoice, or null when there
/// is nothing to say (empty, or fine). [remaining] is what is still owed.
String? paymentAmountMessage(PaymentAmountProblem problem, Money remaining) {
  return switch (problem) {
    PaymentAmountProblem.empty => null,
    PaymentAmountProblem.invalid => 'Valor inválido. Use o formato 1.234,56.',
    PaymentAmountProblem.notPositive => 'Informe um valor maior que zero.',
    PaymentAmountProblem.aboveOwed =>
      'O valor é maior do que falta pagar (${remaining.format()}).',
  };
}
