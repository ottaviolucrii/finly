import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String cardFailureMessage(Failure failure) {
  final code = failure.message;

  if (code.contains('invoice already paid')) {
    return 'Esta fatura já foi paga.';
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