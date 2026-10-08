import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all shows every table', () {
    expect(AuditFilter.all.tables, isEmpty);
  });

  test('transactions include transfers', () {
    expect(AuditFilter.transactions.tables, ['transactions', 'transfers']);
  });

  test('accounts include cards and invoices', () {
    expect(
      AuditFilter.accounts.tables,
      ['accounts', 'credit_card_details', 'credit_card_invoices'],
    );
  });

  test('the others are one table each', () {
    expect(AuditFilter.categories.tables, ['categories']);
    expect(AuditFilter.budgets.tables, ['budgets']);
    expect(AuditFilter.recurring.tables, ['recurring_transactions']);
  });

  test('no table is in two filters', () {
    final seen = <String>[];
    for (final filter in AuditFilter.values) {
      seen.addAll(filter.tables);
    }

    expect(seen.toSet().length, seen.length);
  });
}
