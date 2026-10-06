import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/reports/domain/csv_rules.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const account = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: 0,
    projectedBalanceCents: 0,
  );
  const food = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    icon: 'restaurant',
    colorHex: '#F29D38',
    isDefault: true,
  );

  TransactionEntity tx({
    String id = 't1',
    TransactionType type = TransactionType.expense,
    TransactionStatus status = TransactionStatus.posted,
    int cents = 2590,
    String description = 'Mercado',
    String? categoryId = 'c1',
    String accountId = 'a1',
    DateTime? occurredAt,
    String? transferId,
  }) {
    return TransactionEntity(
      id: id,
      workspaceId: 'w1',
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      status: status,
      amountCents: cents,
      currency: 'BRL',
      description: description,
      occurredAt: occurredAt ?? DateTime(2026, 10, 5, 12),
      transferId: transferId,
    );
  }

  List<String> linesOf(String csv) => csv.trim().split('\r\n');

  group('formatCsvAmount', () {
    test('writes whole and cents with a comma', () {
      expect(formatCsvAmount(2590, negative: false), '25,90');
      expect(formatCsvAmount(300000, negative: false), '3000,00');
    });

    test('pads the cents', () {
      expect(formatCsvAmount(5, negative: false), '0,05');
      expect(formatCsvAmount(105, negative: false), '1,05');
    });

    test('puts the minus sign only on amounts above zero', () {
      expect(formatCsvAmount(2590, negative: true), '-25,90');
      expect(formatCsvAmount(0, negative: true), '0,00');
    });

    test('has no thousands separator and no currency symbol', () {
      expect(formatCsvAmount(123456789, negative: false), '1234567,89');
    });
  });

  group('csvCell', () {
    test('leaves plain text alone', () {
      expect(csvCell('Mercado'), 'Mercado');
    });

    test('quotes a cell with the separator and doubles the quotes', () {
      expect(csvCell('Pão; leite'), '"Pão; leite"');
      expect(csvCell('Disse "oi"'), '"Disse ""oi"""');
    });

    test('quotes a cell with a line break', () {
      expect(csvCell('a\nb'), '"a\nb"');
    });

    test('keeps a spreadsheet from running text as a formula', () {
      expect(csvCell('=SOMA(A1:A2)'), "'=SOMA(A1:A2)");
      expect(csvCell('+55 11 9999'), "'+55 11 9999");
      expect(csvCell('-troco'), "'-troco");
      expect(csvCell('@maria'), "'@maria");
    });

    test('an empty cell stays empty', () {
      expect(csvCell(''), '');
    });
  });

  group('buildTransactionsCsv', () {
    test('starts with the header and has no byte order mark', () {
      final csv = buildTransactionsCsv(const [], const [account], const [food]);

      expect(csv.codeUnitAt(0), isNot(0xFEFF));
      expect(
        linesOf(csv).single,
        'Data;Descrição;Tipo;Status;Categoria;Conta;Moeda;Valor',
      );
    });

    test('ends with a Windows line break', () {
      final csv = buildTransactionsCsv([tx()], const [account], const [food]);

      expect(csv.endsWith('\r\n'), isTrue);
    });

    test('writes dates as year-month-day, which no spreadsheet locale misreads', () {
      final csv = buildTransactionsCsv(
        [
          tx(id: 'a', occurredAt: DateTime(2026, 10, 2, 12)),
          tx(id: 'b', occurredAt: DateTime(2026, 1, 19, 12)),
        ],
        const [account],
        const [food],
      );
      final lines = linesOf(csv);

      expect(lines[1], startsWith('2026-01-19;'));
      expect(lines[2], startsWith('2026-10-02;'));
    });

    test('writes one line per transaction with names, not ids', () {
      final csv = buildTransactionsCsv([tx()], const [account], const [food]);

      expect(
        linesOf(csv)[1],
        '2026-10-05;Mercado;Saída;Confirmada;Alimentação;Nubank;BRL;-25,90',
      );
    });

    test('an income is positive', () {
      final csv = buildTransactionsCsv(
        [tx(type: TransactionType.income, cents: 300000, description: 'Salário')],
        const [account],
        const [food],
      );

      expect(linesOf(csv)[1], endsWith('Entrada;Confirmada;Alimentação;Nubank;BRL;3000,00'));
    });

    test('a pending transaction says so', () {
      final csv = buildTransactionsCsv(
        [tx(status: TransactionStatus.pending)],
        const [account],
        const [food],
      );

      expect(linesOf(csv)[1], contains(';Saída;Pendente;'));
    });

    test('transfer legs are named by direction', () {
      final csv = buildTransactionsCsv(
        [
          tx(id: 'o', type: TransactionType.transferOut, transferId: 'x', categoryId: null),
          tx(id: 'i', type: TransactionType.transferIn, transferId: 'x', categoryId: null),
        ],
        const [account],
        const [food],
      );
      final lines = linesOf(csv);

      expect(lines.any((l) => l.contains('Transferência (saída)') && l.endsWith('-25,90')), isTrue);
      expect(lines.any((l) => l.contains('Transferência (entrada)') && l.endsWith(';25,90')), isTrue);
    });

    test('a missing category or account leaves the cell empty', () {
      final csv = buildTransactionsCsv(
        [tx(categoryId: null, accountId: 'zzz')],
        const [account],
        const [food],
      );

      expect(linesOf(csv)[1], '2026-10-05;Mercado;Saída;Confirmada;;;BRL;-25,90');
    });

    test('lists the oldest first', () {
      final csv = buildTransactionsCsv(
        [
          tx(id: 'late', description: 'Depois', occurredAt: DateTime(2026, 10, 20, 12)),
          tx(id: 'early', description: 'Antes', occurredAt: DateTime(2026, 10, 2, 12)),
        ],
        const [account],
        const [food],
      );
      final lines = linesOf(csv);

      expect(lines[1], contains('Antes'));
      expect(lines[2], contains('Depois'));
    });

    test('protects a description that looks like a formula', () {
      final csv = buildTransactionsCsv(
        [tx(description: '=1+1')],
        const [account],
        const [food],
      );

      expect(linesOf(csv)[1], contains(";'=1+1;"));
    });
  });
}