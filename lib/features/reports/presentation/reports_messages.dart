import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String reportsFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_workspace':
      return 'Workspace inválido.';
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