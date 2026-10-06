import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String authFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'invalid_email':
      return 'Informe um e-mail válido.';
    case 'password_required':
      return 'Informe a senha.';
    case 'invalid_full_name':
      return 'Informe seu nome completo.';
    case 'weak_password':
      return 'A senha precisa ter 8 caracteres, com letras e números.';
    case 'same_password':
      return 'A nova senha deve ser diferente da anterior.';
    case 'invalid_code':
      return 'Código inválido ou expirado. Peça um novo código.';
    case 'terms_not_accepted':
      return 'Aceite os termos para continuar.';
    case 'invalid_credentials':
      return 'E-mail ou senha incorretos.';
    case 'email_not_confirmed':
      return 'Confirme seu e-mail antes de entrar.';
    case 'email_already_registered':
      return 'Este e-mail já está cadastrado.';
    case 'rate_limited':
      return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
    case 'network_error':
      return 'Sem conexão. Verifique sua internet.';
    default:
      return 'Algo deu errado. Tente novamente.';
  }
}