import 'dart:convert';

import 'package:finly/features/import/domain/statement_line.dart';
import 'package:finly/features/import/domain/statement_reading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('amounts', () {
    test('the Brazilian and the international way', () {
      expect(parseAmountCents('-1.234,56'), -123456);
      expect(parseAmountCents('1234.56'), 123456);
      expect(parseAmountCents('R\$ 12,30'), 1230);
      expect(parseAmountCents('12,5'), 1250);
      expect(parseAmountCents('1.234'), 123400);
      expect(parseAmountCents('(12,30)'), -1230);
      expect(parseAmountCents('-25.90'), -2590);
    });

    test('not an amount', () {
      expect(parseAmountCents(''), isNull);
      expect(parseAmountCents('abc'), isNull);
      expect(parseAmountCents('12,345'), isNull);
    });
  });

  group('dates', () {
    test('day first, or ISO', () {
      expect(parseStatementDate('25/10/2026'), DateTime(2026, 10, 25));
      expect(parseStatementDate('5/1/26'), DateTime(2026, 1, 5));
      expect(parseStatementDate('2026-10-25'), DateTime(2026, 10, 25));
      expect(parseStatementDate('25-10-2026'), DateTime(2026, 10, 25));
    });

    test('not a date', () {
      expect(parseStatementDate('31/02/2026'), isNull);
      expect(parseStatementDate('ontem'), isNull);
    });
  });

  group('OFX', () {
    // the old SGML kind: leaf tags do not close; Windows-1252 text
    const sgml = '''OFXHEADER:100
DATA:OFXSGML
CHARSET:1252

<OFX>
<BANKMSGSRSV1><STMTTRNRS><STMTRS>
<CURDEF>BRL
<BANKTRANLIST>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261010120000[-3:BRT]
<TRNAMT>-25.90
<FITID>ABC123
<MEMO>Padaria Pão Quente
</STMTTRN>
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20261011
<TRNAMT>1500.00
<FITID>ABC124
<NAME>Pix recebido
</STMTTRN>
</BANKTRANLIST>
</STMTRS></STMTTRNRS></BANKMSGSRSV1>
</OFX>''';

    test('reads each transaction, with the bank id', () {
      final file = readStatement(decodeStatement(latin1.encode(sgml)));

      expect(file.looksLikeCard, isFalse);
      expect(file.lines, [
        StatementLine(date: DateTime(2026, 10, 10), amountCents: -2590, description: 'Padaria Pão Quente', externalId: 'ABC123'),
        StatementLine(date: DateTime(2026, 10, 11), amountCents: 150000, description: 'Pix recebido', externalId: 'ABC124'),
      ]);
    });

    test('a credit card statement is recognized', () {
      const card = '<OFX><CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS><BANKTRANLIST>'
          '<STMTTRN><DTPOSTED>20261003</DTPOSTED><TRNAMT>-89.90</TRNAMT><FITID>X1</FITID><MEMO>Netflix</MEMO></STMTTRN>'
          '</BANKTRANLIST></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>';
      final file = readStatement(card);

      expect(file.looksLikeCard, isTrue);
      expect(file.lines.single.amountCents, -8990);
      expect(file.lines.single.description, 'Netflix');
    });

    test('a line without amount or date is skipped and counted', () {
      final file = readOfx('<OFX><STMTTRN><DTPOSTED>2026<TRNAMT>-1.00<MEMO>X</STMTTRN></OFX>');

      expect(file.lines, isEmpty);
      expect(file.skipped, 1);
    });
  });

  group('CSV', () {
    test('Nubank checking account (Data, Valor, Identificador, Descrição)', () {
      const csv = 'Data,Valor,Identificador,Descrição\n'
          '01/10/2026,-23.50,abc-1,"Uber *Trip, Centro"\n'
          '02/10/2026,3000.00,abc-2,Transferência recebida\n';
      final file = readStatement(csv);

      expect(file.lines, [
        StatementLine(date: DateTime(2026, 10, 1), amountCents: -2350, description: 'Uber *Trip, Centro', externalId: 'abc-1'),
        StatementLine(date: DateTime(2026, 10, 2), amountCents: 300000, description: 'Transferência recebida', externalId: 'abc-2'),
      ]);
    });

    test('Nubank card (date, title, amount): purchases come positive', () {
      final file = readStatement('date,title,amount\n2026-10-03,Netflix,39.90\n');

      expect(file.lines.single.amountCents, 3990);
      expect(file.lines.single.withSignInverted().amountCents, -3990);
    });

    test('semicolons, a title line before the header, and 1.234,56', () {
      const csv = 'Extrato da conta\n'
          'Data;Histórico;Valor\n'
          '10/10/2026;Aluguel;-1.800,00\n'
          '11/10/2026;Linha quebrada;\n';
      final file = readStatement(csv);

      expect(file.lines.single, StatementLine(date: DateTime(2026, 10, 10), amountCents: -180000, description: 'Aluguel'));
      expect(file.skipped, 1);
    });

    test('a file with no known columns reads nothing', () {
      final file = readStatement('a;b;c\n1;2;3\n');

      expect(file.lines, isEmpty);
    });

    test('quotes with commas and doubled quotes', () {
      expect(splitCsvLine('1,"Bar ""do Zé"", centro",3', ','), ['1', 'Bar "do Zé", centro', '3']);
    });
  });
}
