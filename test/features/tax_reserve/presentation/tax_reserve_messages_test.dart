import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/presentation/tax_reserve_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String text(Failure failure) => taxReserveFailureMessage(failure);

  test('asks for a percentage between 0 and 100', () {
    expect(
      text(const ValidationFailure('invalid_percent')),
      'Informe uma porcentagem entre 0 e 100.',
    );
  });

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
    for (final failure in [
      const ServerFailure('unknown_error'),
      const RuleFailure('violates check constraint "workspaces_tax_reserve_chk"'),
    ]) {
      final message = text(failure);

      expect(message, isNotEmpty);
      expect(message, isNot(contains('constraint')));
      expect(message, isNot(contains('unknown_error')));
    }
  });
}
