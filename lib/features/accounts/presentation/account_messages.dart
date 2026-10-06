import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String accountFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_account_name':
      return 'Informe um nome para a conta (até 80 caracteres).';
    case 'invalid_currency':
      return 'Moeda não suportada.';
    case 'invalid_account':
    case 'invalid_workspace':
      return 'Conta inválida.';
    case 'credit_card_needs_settings':
      return 'Cartões de crédito serão criados em uma tela própria.';
    case 'already_exists':
      return 'Já existe uma conta com esse nome neste workspace.';
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

/// The same, for restoring an archived account: a name clash has a different
/// way out (rename one of the two).
String accountRestoreFailureMessage(Failure failure) {
  if (failure.message == 'already_exists') {
    return 'Já existe uma conta ativa com esse nome. Renomeie uma delas e '
        'tente de novo.';
  }
  return accountFailureMessage(failure);
}