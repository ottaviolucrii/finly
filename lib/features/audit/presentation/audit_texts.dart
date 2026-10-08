import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';

/// The name of a filter on the screen (Portuguese for now; replaced by proper
/// localisation in a later phase).
String auditFilterLabel(AuditFilter filter) {
  switch (filter) {
    case AuditFilter.all:
      return 'Tudo';
    case AuditFilter.transactions:
      return 'Transações';
    case AuditFilter.accounts:
      return 'Contas e cartões';
    case AuditFilter.categories:
      return 'Categorias';
    case AuditFilter.budgets:
      return 'Orçamentos';
    case AuditFilter.recurring:
      return 'Recorrências';
  }
}

/// The text for a failure on the history screen.
String auditFailureMessage(Failure failure) {
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
