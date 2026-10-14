import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/summary/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CategoryChange category(String name, int spent, int previous, {bool other = false}) =>
      CategoryChange(name: name, colorHex: '#F29D38', spentCents: spent, previousCents: previous, isOther: other);

  MonthlyReport report({
    required int income,
    required int expense,
    int previousExpense = 0,
    List<CategoryChange> categories = const [],
    DateTime? month,
  }) =>
      MonthlyReport(
        month: month ?? DateTime(2026, 9),
        byCurrency: [
          CurrencyReport(
            currency: 'BRL',
            incomeCents: income,
            expenseCents: expense,
            previousIncomeCents: 0,
            previousExpenseCents: previousExpense,
            categories: categories,
            topExpenses: const [],
          ),
        ],
      );

  test('the month names, capitalized for titles', () {
    expect(monthName(DateTime(2026, 3)), 'março');
    expect(monthNameCapitalized(DateTime(2026, 9)), 'Setembro');
  });

  group('the headline', () {
    test('less than the month before, with money left over', () {
      final s = monthSummaryOf(report(income: 500000, expense: 220000, previousExpense: 250000))!;

      expect(s.headline, 'Setembro: você gastou 12% a menos que no mês anterior e sobrou R\$ 2.800,00.');
    });

    test('more than the month before, and missing money', () {
      final s = monthSummaryOf(report(income: 100000, expense: 150000, previousExpense: 100000))!;

      expect(s.headline, 'Setembro: você gastou 50% a mais que no mês anterior e faltou R\$ 500,00.');
    });

    test('without a month before, it says how much was spent', () {
      final s = monthSummaryOf(report(income: 300000, expense: 120000))!;

      expect(s.headline, 'Setembro: você gastou R\$ 1.200,00 e sobrou R\$ 1.800,00.');
    });

    test('no expenses at all', () {
      final s = monthSummaryOf(report(income: 300000, expense: 0))!;

      expect(s.headline, 'Setembro: você não teve despesas e sobrou R\$ 3.000,00.');
    });
  });

  group('the lines', () {
    test('what came in and went out, and what was left', () {
      final s = monthSummaryOf(report(income: 500000, expense: 220000))!;

      expect(s.lines[0], const SummaryLine(SummaryLineKind.flow, 'Entraram R\$ 5.000,00 e saíram R\$ 2.200,00.'));
      expect(s.lines[1], const SummaryLine(SummaryLineKind.net, 'Sobrou R\$ 2.800,00.'));
    });

    test('where it grew the most (at least R\$ 20 and 10%), and where it spent the most', () {
      final s = monthSummaryOf(report(
        income: 500000,
        expense: 200000,
        previousExpense: 180000,
        categories: [
          category('Mercado', 90000, 80000),
          category('Restaurantes', 42000, 28000),
          category('Lazer', 10500, 10000),
          category('Outras', 57500, 0, other: true),
        ],
      ))!;

      final texts = s.lines.map((l) => l.text).toList();
      expect(texts, contains('Onde mais cresceu: Restaurantes, de R\$ 280,00 para R\$ 420,00.'));
      expect(texts, contains('Onde mais gastou: Mercado, R\$ 900,00 (45% das despesas).'));
    });

    test('a small rise is not news', () {
      final s = monthSummaryOf(report(
        income: 100000,
        expense: 50000,
        previousExpense: 49000,
        categories: [category('Mercado', 50000, 49000)],
      ))!;

      expect(s.lines.where((l) => l.kind == SummaryLineKind.rise), isEmpty);
    });

    test('the group "Outras" never counts as the place that spent the most', () {
      final s = monthSummaryOf(report(
        income: 100000,
        expense: 90000,
        categories: [category('Outras', 60000, 0, other: true), category('Mercado', 30000, 0)],
      ))!;

      expect(s.lines.last.text, startsWith('Onde mais gastou: Mercado'));
    });
  });

  test('a month without movement has nothing to tell', () {
    final s = monthSummaryOf(report(income: 0, expense: 0))!;

    expect(s.isEmpty, isTrue);
  });

  test('a report without any currency has no summary', () {
    expect(monthSummaryOf(MonthlyReport(month: DateTime(2026, 9), byCurrency: const [])), isNull);
  });
}
