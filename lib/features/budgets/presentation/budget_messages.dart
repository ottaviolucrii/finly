import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String budgetFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_category':
      return 'Escolha uma categoria.';
    case 'invalid_limit':
      return 'Informe um limite maior que zero.';
    case 'invalid_currency':
      return 'Moeda não suportada.';
    case 'invalid_budget':
    case 'invalid_workspace':
      return 'Orçamento inválido.';
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