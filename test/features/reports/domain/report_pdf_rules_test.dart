import 'package:finly/features/reports/domain/report_pdf_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pdfMonthTitle', () {
    test('writes the month in full, with a capital letter', () {
      expect(pdfMonthTitle(DateTime(2026, 10)), 'Outubro de 2026');
      expect(pdfMonthTitle(DateTime(2027, 1)), 'Janeiro de 2027');
    });

    test('keeps the accent of março', () {
      expect(pdfMonthTitle(DateTime(2026, 3)), 'Março de 2026');
    });

    test('has a name for every month', () {
      for (var month = 1; month <= 12; month++) {
        expect(pdfMonthTitle(DateTime(2026, month)), endsWith(' de 2026'));
      }
    });
  });

  group('pdfFileName', () {
    test('has the year and the month', () {
      expect(pdfFileName(DateTime(2026, 10)), 'finly-relatorio-2026-10.pdf');
    });

    test('pads the month to two digits', () {
      expect(pdfFileName(DateTime(2026, 3, 15)), 'finly-relatorio-2026-03.pdf');
    });
  });

  group('pdfChangeText', () {
    test('a rise has a plus sign', () {
      expect(pdfChangeText(150, 100), '+50%');
    });

    test('a fall has a minus sign', () {
      expect(pdfChangeText(75, 100), '-25%');
    });

    test('no change is 0%', () {
      expect(pdfChangeText(100, 100), '0%');
    });

    test('says there is no data when the month before had nothing', () {
      expect(pdfChangeText(100, 0), 'sem dados');
    });

    test('is a dash when both months are empty', () {
      expect(pdfChangeText(0, 0), '-');
    });

    test('never uses an arrow, which the standard font does not have', () {
      for (final text in [
        pdfChangeText(150, 100),
        pdfChangeText(50, 100),
        pdfChangeText(100, 100),
        pdfChangeText(1, 0),
      ]) {
        expect(text.codeUnits.every((unit) => unit < 128), isTrue, reason: text);
      }
    });
  });

  group('pdfSignedMoney', () {
    test('a positive result has a plus sign', () {
      expect(pdfSignedMoney(12345, 'BRL'), startsWith('+ '));
      expect(pdfSignedMoney(12345, 'BRL'), contains('123,45'));
    });

    test('a negative result keeps its minus sign', () {
      expect(pdfSignedMoney(-12345, 'BRL'), contains('-'));
      expect(pdfSignedMoney(-12345, 'BRL'), isNot(startsWith('+')));
    });

    test('zero has no sign', () {
      expect(pdfSignedMoney(0, 'BRL'), isNot(startsWith('+')));
    });
  });

  test('pdfGeneratedText has the date and the time', () {
    expect(
      pdfGeneratedText(DateTime(2026, 10, 7, 9, 5)),
      'gerado em 07/10/2026 às 09:05',
    );
  });
}
