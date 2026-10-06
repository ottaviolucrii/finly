import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty filter narrows nothing', () {
    const filter = TransactionFilter();

    expect(filter.isActive, isFalse);
    expect(filter.pickerCount, 0);
  });

  test('counts only the pickers, not the search box', () {
    const filter = TransactionFilter(
      search: 'mercado',
      type: TransactionType.expense,
      status: TransactionStatus.pending,
      accountId: 'a1',
      categoryId: 'c1',
    );

    expect(filter.pickerCount, 4);
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

  test('withSearch changes the text and keeps the pickers', () {
    const filter = TransactionFilter(
      type: TransactionType.income,
      accountId: 'a1',
    );

    final searched = filter.withSearch('salário');

    expect(searched.search, 'salário');
    expect(searched.type, TransactionType.income);
    expect(searched.accountId, 'a1');
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
}