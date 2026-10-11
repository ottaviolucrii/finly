import 'package:finly/features/budgets/presentation/pages/budgets_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final october = DateTime(2026, 10);

  test('what is left split over the days left, counting today', () {
    // 11/10 to 31/10 is 21 days.
    expect(dailyAllowanceCents(42000, october, DateTime(2026, 10, 11)), 2000);
  });

  test('on the last day, all of it', () {
    expect(dailyAllowanceCents(5000, october, DateTime(2026, 10, 31)), 5000);
  });

  test('nothing when nothing is left or the limit was passed', () {
    expect(dailyAllowanceCents(0, october, DateTime(2026, 10, 11)), isNull);
    expect(dailyAllowanceCents(-1200, october, DateTime(2026, 10, 11)), isNull);
  });

  test('nothing for another month', () {
    expect(dailyAllowanceCents(42000, DateTime(2026, 9), DateTime(2026, 10, 11)), isNull);
    expect(dailyAllowanceCents(42000, DateTime(2026, 11), DateTime(2026, 10, 11)), isNull);
  });
}
