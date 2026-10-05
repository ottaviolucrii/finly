import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String recurringFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_account':
      return 'Escolha uma conta.';
    case 'invalid_amount':
      return 'Informe um valor maior que zero.';
    case 'invalid_description':
      return 'Informe uma descrição (até 200 caracteres).';
    case 'invalid_interval':
      return 'O intervalo vai de 1 a 52.';
    case 'invalid_end_date':
      return 'A data final não pode ser antes da inicial.';
    case 'invalid_transaction_type':
    case 'invalid_recurring':
    case 'invalid_workspace':
      return 'Recorrência inválida.';
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