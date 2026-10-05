import 'package:finly/features/cards/domain/installment_split.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an exact division gives equal parts', () {
    expect(splitInstallments(90000, 3), [30000, 30000, 30000]);
  });

  test('the first part absorbs the cents left over', () {
    expect(splitInstallments(100001, 3), [33335, 33333, 33333]);
    expect(splitInstallments(100, 3), [34, 33, 33]);
  });

  test('two parts', () {
    expect(splitInstallments(101, 2), [51, 50]);
  });

  test('one part is the whole amount', () {
    expect(splitInstallments(12345, 1), [12345]);
  });

  test('the parts always add up to the total', () {
    for (var parts = 1; parts <= 48; parts++) {
      for (final total in [1, 99, 100, 100001, 999999, 123456789]) {
        if (total < parts) continue;
        final split = splitInstallments(total, parts);
        expect(split.length, parts);
        expect(split.fold<int>(0, (sum, part) => sum + part), total);
      }
    }
  });

  test('fewer than one part is an error', () {
    expect(() => splitInstallments(1000, 0), throwsArgumentError);
  });
}