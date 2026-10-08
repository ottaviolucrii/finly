import 'package:finly/core/error/failure.dart';
import 'package:finly/features/data_export/presentation/data_export_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String text(Failure failure) => dataExportFailureMessage(failure);

  test('says the share sheet could not be opened', () {
    expect(text(const ServerFailure('share_failed')), contains('compartilhamento'));
  });

  test('says the session ended', () {
    expect(text(const AuthFailure('not_authenticated')), contains('sessão'));
  });

  test('says there is no connection', () {
    expect(text(const NetworkFailure('network_error')), contains('conexão'));
  });

  test('says there is no access', () {
    expect(text(const PermissionFailure('forbidden')), contains('acesso'));
  });

  test('anything else gets a message and never the raw text', () {
    final message = text(const ServerFailure('unknown_error'));

    expect(message, isNotEmpty);
    expect(message, isNot(contains('unknown_error')));
  });

  test('the message about a partial file is not empty', () {
    expect(dataExportTruncatedMessage, contains('grande'));
  });
}
