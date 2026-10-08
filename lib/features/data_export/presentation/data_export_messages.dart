import 'package:finly/core/error/failure.dart';

/// The text for a failure when exporting the data (Portuguese for now;
/// replaced by proper localisation in a later phase).
String dataExportFailureMessage(Failure failure) {
  switch (failure.message) {
    case 'share_failed':
      return 'Não foi possível abrir o compartilhamento. Tente de novo.';
    case 'not_authenticated':
      return 'Sua sessão expirou. Entre novamente.';
    case 'network_error':
      return 'Sem conexão. Verifique sua internet e tente de novo.';
    case 'forbidden':
      return 'Você não tem acesso a estes dados.';
    default:
      return 'Não foi possível exportar seus dados. Tente de novo.';
  }
}

/// Said when a table was longer than the limit and the file holds only a part.
const String dataExportTruncatedMessage =
    'Seu histórico é muito grande: o arquivo tem só a parte mais antiga de '
    'alguns dados.';
