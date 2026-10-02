import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String workspaceFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_workspace_name':
      return 'Informe um nome para o workspace (até 80 caracteres).';
    case 'invalid_tax_id':
      return 'Documento inválido. Confira os números e tente de novo.';
    case 'workspace_type_already_exists':
      return 'Você já tem um workspace deste tipo.';
    case 'not_authenticated':
      return 'Sua sessão expirou. Entre novamente.';
    case 'network_error':
      return 'Sem conexão. Verifique sua internet.';
    default:
      return 'Não foi possível criar o workspace. Tente novamente.';
  }
}

String switchWorkspaceFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_workspace':
    case 'forbidden':
      return 'Você não tem acesso a este workspace.';
    case 'not_authenticated':
      return 'Sua sessão expirou. Entre novamente.';
    case 'network_error':
      return 'Sem conexão. Verifique sua internet.';
    default:
      return 'Não foi possível trocar de workspace. Tente novamente.';
  }
}