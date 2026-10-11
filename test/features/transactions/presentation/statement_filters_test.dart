import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/presentation/statement_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monthRange', () {
    test('goes from the first to the last day', () {
      expect(monthRange(DateTime(2026, 10, 17)), (DateTime(2026, 10), DateTime(2026, 10, 31)));
      expect(monthRange(DateTime(2026, 11, 1)), (DateTime(2026, 11), DateTime(2026, 11, 30)));
    });

    test('knows February in leap years', () {
      expect(monthRange(DateTime(2028, 2, 10)).$2, DateTime(2028, 2, 29));
      expect(monthRange(DateTime(2027, 2, 10)).$2, DateTime(2027, 2, 28));
    });

    test('works in December', () {
      expect(monthRange(DateTime(2026, 12, 25)), (DateTime(2026, 12), DateTime(2026, 12, 31)));
    });
  });

  group('filterForMonth and monthOfFilter', () {
    test('a month filter is read back as that month', () {
      final filter = filterForMonth(const TransactionFilter(), DateTime(2026, 10, 10));

      expect(filter.from, DateTime(2026, 10));
      expect(filter.to, DateTime(2026, 10, 31));
      expect(monthOfFilter(filter), DateTime(2026, 10));
    });

    test('keeps everything else of the filter', () {
      const before = TransactionFilter(search: 'mercado', type: TransactionType.expense, accountId: 'a1', categoryId: 'c1');

      final after = filterForMonth(before, DateTime(2026, 3, 5));

      expect(after.search, 'mercado');
      expect(after.type, TransactionType.expense);
      expect(after.accountId, 'a1');
      expect(after.categoryId, 'c1');
    });

    test('no period is not a month', () {
      expect(monthOfFilter(const TransactionFilter()), isNull);
    });

    test('a period that is not a whole month is not a month', () {
      expect(monthOfFilter(TransactionFilter(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 31))), isNull);
      expect(monthOfFilter(TransactionFilter(from: DateTime(2026, 10), to: DateTime(2026, 11, 30))), isNull);
      expect(monthOfFilter(TransactionFilter(from: DateTime(2026, 10))), isNull);
    });

    test('moving across a year works', () {
      final january = filterForMonth(const TransactionFilter(), DateTime(2026, 12 + 1));
      expect(monthOfFilter(january), DateTime(2027, 1));
    });
  });

  group('quick filters', () {
    test('no type and no status is "Tudo"', () {
      expect(quickOf(const TransactionFilter()), QuickFilter.all);
    });

    test('each chip is recognised', () {
      expect(quickOf(const TransactionFilter(type: TransactionType.income)), QuickFilter.income);
      expect(quickOf(const TransactionFilter(type: TransactionType.expense)), QuickFilter.expense);
      expect(quickOf(const TransactionFilter(status: TransactionStatus.pending)), QuickFilter.pending);
    });

    test('a mix made in the sheet matches no chip', () {
      expect(quickOf(const TransactionFilter(type: TransactionType.expense, status: TransactionStatus.pending)), isNull);
      expect(quickOf(const TransactionFilter(status: TransactionStatus.posted)), isNull);
    });

    test('a chip sets only the type and the status', () {
      final month = filterForMonth(const TransactionFilter(search: 'luz', accountId: 'a1'), DateTime(2026, 10));

      final income = filterWithQuick(month, QuickFilter.income);
      expect(income.type, TransactionType.income);
      expect(income.status, isNull);
      expect(income.search, 'luz');
      expect(income.accountId, 'a1');
      expect(monthOfFilter(income), DateTime(2026, 10));

      final pending = filterWithQuick(income, QuickFilter.pending);
      expect(pending.type, isNull);
      expect(pending.status, TransactionStatus.pending);

      final all = filterWithQuick(pending, QuickFilter.all);
      expect(all.type, isNull);
      expect(all.status, isNull);
    });
  });

  group('sheetFilterCount', () {
    test('the month and the chip do not count', () {
      final filter = filterWithQuick(filterForMonth(const TransactionFilter(), DateTime(2026, 10)), QuickFilter.expense);
      expect(sheetFilterCount(filter), 0);
    });

    test('an account or a category set in the sheet count', () {
      final filter = filterForMonth(const TransactionFilter(accountId: 'a1', categoryId: 'c1'), DateTime(2026, 10));
      expect(sheetFilterCount(filter), 2);
    });

    test('a custom period counts', () {
      expect(sheetFilterCount(TransactionFilter(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 9))), 1);
    });

    test('a mix of type and status from the sheet counts both', () {
      expect(sheetFilterCount(const TransactionFilter(type: TransactionType.expense, status: TransactionStatus.pending)), 2);
    });
  });

}
