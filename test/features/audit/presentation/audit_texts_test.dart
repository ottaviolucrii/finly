import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/presentation/audit_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every filter has a name on the screen', () {
    expect(auditFilterLabel(AuditFilter.all), 'Tudo');
    expect(auditFilterLabel(AuditFilter.transactions), 'Transações');
    expect(auditFilterLabel(AuditFilter.accounts), 'Contas e cartões');
    expect(auditFilterLabel(AuditFilter.categories), 'Categorias');
    expect(auditFilterLabel(AuditFilter.budgets), 'Orçamentos');
    expect(auditFilterLabel(AuditFilter.recurring), 'Recorrências');
  });

  test('no two filters have the same name', () {
    final names = AuditFilter.values.map(auditFilterLabel).toSet();

    expect(names.length, AuditFilter.values.length);
  });

  group('auditFailureMessage', () {
    String text(Failure failure) => auditFailureMessage(failure);

    test('says the workspace is invalid', () {
      expect(text(const ValidationFailure('invalid_workspace')), 'Workspace inválido.');
    });

    test('says there is no access', () {
      expect(text(const PermissionFailure('forbidden')), contains('acesso'));
    });

    test('says the session ended', () {
      expect(text(const AuthFailure('not_authenticated')), contains('sessão'));
    });

    test('says there is no connection', () {
      expect(text(const NetworkFailure('network_error')), contains('conexão'));
    });

    test('anything else gets a message and never the raw text', () {
      final message = text(const ServerFailure('unknown_error'));

      expect(message, isNotEmpty);
      expect(message, isNot(contains('unknown_error')));
    });
  });
}
