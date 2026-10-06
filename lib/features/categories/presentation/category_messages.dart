import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String categoryFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_category_name':
      return 'Informe um nome (até 60 caracteres).';
    case 'invalid_icon':
      return 'Escolha um ícone.';
    case 'invalid_color':
      return 'Escolha uma cor.';
    case 'already_exists':
      return 'Já existe uma categoria com esse nome (ela pode estar arquivada).';
    case 'invalid_category':
    case 'invalid_workspace':
      return 'Categoria inválida.';
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