import 'package:finly/core/error/failure.dart';

/// The text for a failure on the tax reserve screen (Portuguese for now;
/// replaced by proper localisation in a later phase).
String taxReserveFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_percent':
      return 'Informe uma porcentagem entre 0 e 100.';
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
