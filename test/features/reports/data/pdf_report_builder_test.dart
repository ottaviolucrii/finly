import 'dart:io';
import 'dart:typed_data';

import 'package:finly/features/reports/data/pdf_report_builder.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fonts are read from the project folder: `flutter test` runs there.
Future<ByteData> _fontFromDisk(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

void main() {
  final builder = PdfReportBuilder(loadAsset: _fontFromDisk);
  final month = DateTime(2026, 10);
  final now = DateTime(2026, 10, 7, 9, 5);

  TransactionEntity expense(String description, int cents, {bool pending = false}) {
    return TransactionEntity(
      id: description,
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: 'c1',
      type: TransactionType.expense,
      status: pending ? TransactionStatus.pending : TransactionStatus.posted,
      amountCents: cents,
      currency: 'BRL',
      description: description,
      occurredAt: DateTime(2026, 10, 5, 12),
    );
  }

  CurrencyReport currencyReport({
    String currency = 'BRL',
    List<CategoryChange> categories = const [],
    List<TransactionEntity> top = const [],
    int income = 500000,
    int expenses = 300000,
  }) {
    return CurrencyReport(
      currency: currency,
      incomeCents: income,
      expenseCents: expenses,
      previousIncomeCents: 400000,
      previousExpenseCents: 350000,
      categories: categories,
      topExpenses: top,
    );
  }

  Future<List<int>> draw(List<CurrencyReport> currencies, {String workspace = 'Pessoal'}) {
    return builder.build(
      report: MonthlyReport(month: month, byCurrency: currencies),
      workspaceName: workspace,
      generatedAt: now,
    );
  }

  bool isPdf(List<int> bytes) {
    return bytes.length > 5 &&
        String.fromCharCodes(bytes.take(5)) == '%PDF-' &&
        String.fromCharCodes(bytes.skip(bytes.length - 8)).contains('%%EOF');
  }

  test('draws a PDF document', () async {
    final bytes = await draw([
      currencyReport(
        categories: const [
          CategoryChange(name: 'Mercado', colorHex: '#F29D38', spentCents: 120000, previousCents: 100000),
          CategoryChange(name: 'Transporte', colorHex: '#1060E3', spentCents: 60000, previousCents: 0),
        ],
        top: [expense('Supermercado', 45000), expense('Aluguel', 150000, pending: true)],
      ),
    ]);

    expect(isPdf(bytes), isTrue);
    expect(bytes.length, greaterThan(1000));
  });

  test('draws a month with no spending and no expenses', () async {
    final bytes = await draw([currencyReport()]);

    expect(isPdf(bytes), isTrue);
  });

  test('draws one section for each currency', () async {
    final one = await draw([currencyReport()]);
    final two = await draw([currencyReport(), currencyReport(currency: 'USD')]);

    expect(isPdf(two), isTrue);
    expect(two.length, greaterThan(one.length));
  });

  test('draws accents, a long description and a negative result', () async {
    final bytes = await draw(
      [
        currencyReport(
          income: 100000,
          expenses: 250000,
          categories: const [
            CategoryChange(name: 'Educação e saúde', colorHex: '#8E24AA', spentCents: 250000, previousCents: 90000),
          ],
          top: [expense('Mensalidade da faculdade de ciências econômicas, parcela única à vista', 250000)],
        ),
      ],
      workspace: 'Açaí & Cia Ltda',
    );

    expect(isPdf(bytes), isTrue);
  });

  test('draws without a workspace name', () async {
    final bytes = await draw([currencyReport()], workspace: '');

    expect(isPdf(bytes), isTrue);
  });

  test('a colour that is not a hex code does not break it', () async {
    final bytes = await draw([
      currencyReport(
        categories: const [
          CategoryChange(name: 'Outras', colorHex: 'azul', spentCents: 1000, previousCents: 0, isOther: true),
          CategoryChange(name: 'Sem cor', colorHex: '', spentCents: 500, previousCents: 0),
        ],
      ),
    ]);

    expect(isPdf(bytes), isTrue);
  });

  test('uses the Inter fonts of the app, regular and bold', () async {
    final paths = <String>[];
    final tracking = PdfReportBuilder(
      loadAsset: (path) {
        paths.add(path);
        return _fontFromDisk(path);
      },
    );

    await tracking.build(
      report: MonthlyReport(month: month, byCurrency: [currencyReport()]),
      workspaceName: 'Pessoal',
      generatedAt: now,
    );

    expect(paths, [PdfReportBuilder.regularFontPath, PdfReportBuilder.boldFontPath]);
  });

  test('reads the fonts only once', () async {
    var reads = 0;
    final counting = PdfReportBuilder(
      loadAsset: (path) {
        reads++;
        return _fontFromDisk(path);
      },
    );
    final report = MonthlyReport(month: month, byCurrency: [currencyReport()]);

    await counting.build(report: report, workspaceName: 'A', generatedAt: now);
    await counting.build(report: report, workspaceName: 'B', generatedAt: now);

    expect(reads, 2);
  });

  test('a font that cannot be read makes the drawing fail, and the next try reads it again', () async {
    var failing = true;
    final flaky = PdfReportBuilder(
      loadAsset: (path) {
        if (failing) throw StateError('no font');
        return _fontFromDisk(path);
      },
    );
    final report = MonthlyReport(month: month, byCurrency: [currencyReport()]);

    await expectLater(
      flaky.build(report: report, workspaceName: 'A', generatedAt: now),
      throwsStateError,
    );

    failing = false;
    final bytes = await flaky.build(report: report, workspaceName: 'A', generatedAt: now);
    expect(isPdf(bytes), isTrue);
  });

  test('the bundled fonts are in the project', () {
    expect(File(PdfReportBuilder.regularFontPath).existsSync(), isTrue);
    expect(File(PdfReportBuilder.boldFontPath).existsSync(), isTrue);
  });

  test('a very long table goes on to more pages', () async {
    final few = await draw([currencyReport()]);
    final many = await draw([
      currencyReport(
        categories: [
          for (var i = 0; i < 80; i++)
            CategoryChange(
              name: 'Categoria $i',
              colorHex: '#1060E3',
              spentCents: 1000 + i,
              previousCents: 900,
            ),
        ],
        top: [for (var i = 0; i < 40; i++) expense('Despesa número $i', 5000 + i)],
      ),
    ]);

    expect(isPdf(many), isTrue);
    expect(many.length, greaterThan(few.length));
  });
}
