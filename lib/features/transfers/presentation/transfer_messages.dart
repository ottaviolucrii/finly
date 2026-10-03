import 'package:finly/core/error/failure.dart';

/// Turns a failure code into text for the user (Portuguese for now;
/// replaced by proper localisation in a later phase).
String transferFailureMessage(Failure failure) {
  final code = failure.message;

  // Messages raised by the database function (sql/03_logic.sql).
  if (code.contains('inside one workspace')) {
    return 'Transferências entre contas devem ficar no mesmo workspace.';
  }
  if (code.contains('destination amount is required')) {
    return 'Informe o valor recebido: as moedas são diferentes.';
  }
  if (code.contains('amounts must match')) {
    return 'Os valores devem ser iguais quando a moeda é a mesma.';
  }
  if (code.contains('owner withdrawal')) {
    return 'A retirada vai do workspace da empresa para o pessoal.';
  }
  if (code.contains('owner contribution')) {
    return 'O aporte vai do workspace pessoal para o da empresa.';
  }
  if (code.contains('must differ')) {
    return 'Escolha duas contas diferentes.';
  }

  switch (code) {
    case 'invalid_account':
    case 'same_account':
      return 'Escolha duas contas diferentes.';
    case 'invalid_amount':
      return 'Informe um valor maior que zero.';
    case 'invalid_description':
      return 'Informe uma descrição (até 200 caracteres).';
    case 'destination_amount_required':
      return 'Informe o valor recebido: as moedas são diferentes.';
    case 'amounts_must_match':
      return 'Os valores devem ser iguais quando a moeda é a mesma.';
    case 'invalid_transfer':
      return 'Transferência inválida.';
    case 'forbidden':
      return 'Você não tem acesso a uma das contas.';
    case 'not_authenticated':
      return 'Sua sessão expirou. Entre novamente.';
    case 'network_error':
      return 'Sem conexão. Verifique sua internet.';
    default:
      return 'Algo deu errado. Tente novamente.';
  }
}