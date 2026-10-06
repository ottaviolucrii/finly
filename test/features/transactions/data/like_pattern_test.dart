import 'package:finly/features/transactions/data/like_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain text is left as it is', () {
    expect(escapeLikePattern('mercado'), 'mercado');
    expect(escapeLikePattern('Conta de luz 2026'), 'Conta de luz 2026');
  });

  test('a percent sign is searched literally', () {
    expect(escapeLikePattern('100%'), r'100\%');
  });

  test('an underscore is searched literally', () {
    expect(escapeLikePattern('a_b'), r'a\_b');
  });

  test('a backslash is escaped first, so the others stay correct', () {
    expect(escapeLikePattern(r'a\b'), r'a\\b');
    expect(escapeLikePattern(r'\%'), r'\\\%');
  });
}