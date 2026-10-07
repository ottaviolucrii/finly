import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reports/presentation/pdf_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String text(Failure failure) => pdfFailureMessage(failure);

  test('says the PDF could not be made', () {
    expect(
      text(const ServerFailure('pdf_failed')),
      'Não foi possível gerar o PDF. Tente de novo.',
    );
  });

  test('says there is nothing for the report', () {
    expect(
      text(const ValidationFailure('nothing_to_export')),
      'Não há movimentações neste mês para o relatório.',
    );
  });

  test('says the share sheet could not be opened', () {
    expect(text(const ServerFailure('share_failed')), contains('compartilhamento'));
  });

  test('says there is no connection', () {
    expect(text(const NetworkFailure('network_error')), contains('conexão'));
  });

  test('anything else gets a message and never the raw text', () {
    final message = text(const ServerFailure('unknown_error'));

    expect(message, isNotEmpty);
    expect(message, isNot(contains('unknown_error')));
  });
}
