import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String settingsFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'password_required':
      return 'Informe a senha.';
    case 'invalid_credentials':
      return 'Senha atual incorreta.';
    case 'weak_password':
      return 'A nova senha precisa ter 8 caracteres, com letras e números.';
    case 'same_password':
      return 'A nova senha deve ser diferente da atual.';
    case 'confirmation_mismatch':
      return 'Digite EXCLUIR para confirmar.';
    case 'rate_limited':
      return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
    case 'not_authenticated':
      return 'Sua sessão expirou. Entre novamente.';
    case 'network_error':
      return 'Sem conexão. Verifique sua internet.';
    default:
      return 'Algo deu errado. Tente novamente.';
  }
}