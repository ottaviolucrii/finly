import 'package:finly/features/cards/domain/payment_amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaymentAmountCheck check(String text, {int remaining = 33335}) {
    return checkPaymentAmount(text, currency: 'BRL', remainingCents: remaining);
  }

  group('a valid amount', () {
    test('is read in Brazilian format', () {
      expect(check('100,00').cents, 10000);
      expect(check('100,5').cents, 10050);
      expect(check('100').cents, 10000);
    });

    test('with thousands separators', () {
      final result = check('1.234,56', remaining: 500000);

      expect(result.cents, 123456);
      expect(result.isValid, isTrue);
    });

    test('with the currency symbol', () {
      expect(check(r'R$ 100,00').cents, 10000);
    });

    test('with spaces around it', () {
      expect(check('  50,00  ').cents, 5000);
    });

    test('one cent is the least that can be paid', () {
      expect(check('0,01').cents, 1);
    });

    test('has no problem', () {
      expect(check('100,00').problem, isNull);
    });
  });

  group('everything that is still owed', () {
    test('is the full payment', () {
      final result = check('333,35');

      expect(result.cents, 33335);
      expect(result.isFull, isTrue);
    });

    test('a smaller amount is a part', () {
      expect(check('333,34').isFull, isFalse);
    });

    test('when only one cent is owed, one cent is the full payment', () {
      expect(check('0,01', remaining: 1).isFull, isTrue);
    });
  });

  group('problems', () {
    test('nothing typed', () {
      expect(check('').problem, PaymentAmountProblem.empty);
      expect(check('   ').problem, PaymentAmountProblem.empty);
    });

    test('not an amount', () {
      expect(check('abc').problem, PaymentAmountProblem.invalid);
      expect(check('1,2,3').problem, PaymentAmountProblem.invalid);
      expect(check('12,345').problem, PaymentAmountProblem.invalid);
    });

    test('zero', () {
      expect(check('0').problem, PaymentAmountProblem.notPositive);
      expect(check('0,00').problem, PaymentAmountProblem.notPositive);
    });

    test('negative', () {
      expect(check('-5').problem, PaymentAmountProblem.notPositive);
    });

    test('more than what is owed, by one cent', () {
      expect(check('333,36').problem, PaymentAmountProblem.aboveOwed);
    });

    test('far more than what is owed', () {
      expect(check('999999').problem, PaymentAmountProblem.aboveOwed);
    });

    test('a problem has no amount', () {
      expect(check('abc').cents, isNull);
      expect(check('abc').isValid, isFalse);
      expect(check('abc').isFull, isFalse);
    });
  });

  test('two checks of the same text are equal', () {
    expect(check('100'), check('100'));
    expect(check('100'), isNot(check('200')));
  });
}
