import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty filter narrows nothing', () {
    const filter = TransactionFilter();

    expect(filter.isActive, isFalse);
    expect(filter.pickerCount, 0);
    expect(filter.hasPeriod, isFalse);
  });

  test('counts only the pickers, not the search box', () {
    final filter = TransactionFilter(
      search: 'mercado',
      type: TransactionType.expense,
      status: TransactionStatus.pending,
      accountId: 'a1',
      categoryId: 'c1',
      from: DateTime(2026, 10, 1),
    );

    expect(filter.pickerCount, 5);
    expect(filter.isActive, isTrue);
  });

  test('a search alone makes the filter active, but adds no badge', () {
    const filter = TransactionFilter(search: 'aluguel');

    expect(filter.isActive, isTrue);
    expect(filter.pickerCount, 0);
  });

  test('blank spaces in the search do not count', () {
    expect(const TransactionFilter(search: '   ').isActive, isFalse);
  });

  test('withSearch changes the text and keeps the pickers and the period', () {
    final filter = TransactionFilter(
      type: TransactionType.income,
      accountId: 'a1',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );

    final searched = filter.withSearch('salário');

    expect(searched.search, 'salário');
    expect(searched.type, TransactionType.income);
    expect(searched.accountId, 'a1');
    expect(searched.from, DateTime(2026, 10, 1));
    expect(searched.to, DateTime(2026, 10, 31));
  });

  test('filters with the same values are equal', () {
    expect(
      const TransactionFilter(search: 'a', type: TransactionType.expense),
      const TransactionFilter(search: 'a', type: TransactionType.expense),
    );
    expect(
      const TransactionFilter(search: 'a'),
      isNot(const TransactionFilter(search: 'b')),
    );
  });

  group('period', () {
    test('a start day alone is a period and counts as one picker', () {
      final filter = TransactionFilter(from: DateTime(2026, 10, 1));

      expect(filter.hasPeriod, isTrue);
      expect(filter.pickerCount, 1);
      expect(filter.isActive, isTrue);
    });

    test('an end day alone is a period too', () {
      final filter = TransactionFilter(to: DateTime(2026, 10, 31));

      expect(filter.hasPeriod, isTrue);
      expect(filter.pickerCount, 1);
    });

    test('a start and an end day count as a single picker', () {
      final filter = TransactionFilter(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );

      expect(filter.pickerCount, 1);
    });

    test('filters with different periods are not equal', () {
      expect(
        TransactionFilter(from: DateTime(2026, 10, 1)),
        isNot(TransactionFilter(from: DateTime(2026, 9, 1))),
      );
      expect(
        TransactionFilter(from: DateTime(2026, 10, 1)),
        TransactionFilter(from: DateTime(2026, 10, 1)),
      );
    });
  });
}