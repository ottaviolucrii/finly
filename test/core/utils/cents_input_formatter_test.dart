import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = CentsInputFormatter();

  TextEditingValue type(String before, String after) => formatter.formatEditUpdate(
        TextEditingValue(text: before),
        TextEditingValue(text: after),
      );

  group('centsFromInput', () {
    test('only the digits count, the last two are the cents', () {
      expect(centsFromInput('53,50'), 5350);
      expect(centsFromInput('1.234,56'), 123456);
      expect(centsFromInput('0,05'), 5);
    });

    test('nothing typed is zero', () {
      expect(centsFromInput(''), 0);
      expect(centsFromInput(',.'), 0);
    });

    test('never more than the longest amount', () {
      expect(centsFromInput('9999999999999999'), 999999999999);
    });
  });

  test('formatCentsInput groups thousands and shows two decimals', () {
    expect(formatCentsInput(5), '0,05');
    expect(formatCentsInput(5350), '53,50');
    expect(formatCentsInput(123456789), '1.234.567,89');
  });

  group('CentsInputFormatter', () {
    test('each digit moves the comma, like in bank apps', () {
      expect(type('', '5').text, '0,05');
      expect(type('0,05', '0,053').text, '0,53');
      expect(type('0,53', '0,535').text, '5,35');
      expect(type('5,35', '5,350').text, '53,50');
    });

    test('deleting a digit moves it back', () {
      expect(type('53,50', '53,5').text, '5,35');
      expect(type('0,05', '0,0').text, isEmpty);
    });

    test('letters, dots and extra commas are dropped', () {
      expect(type('', '58.5333').text, '5.853,33');
      expect(type('', 'R\$ 12a,3').text, '1,23');
    });

    test('zeros typed first do not count', () {
      expect(type('', '0').text, isEmpty);
      expect(type('', '007').text, '0,07');
    });

    test('the cursor stays at the end', () {
      final value = type('', '5350');
      expect(value.selection.baseOffset, value.text.length);
    });

    test('a digit beyond the longest amount is refused', () {
      final full = formatCentsInput(999999999999);
      expect(type(full, '${full}9').text, full);
    });
  });

  group('with a minus sign (opening balances)', () {
    const signed = CentsInputFormatter(allowNegative: true);

    TextEditingValue typeSigned(String before, String after) => signed.formatEditUpdate(
          TextEditingValue(text: before),
          TextEditingValue(text: after),
        );

    test('"-" makes it negative, wherever it is typed', () {
      expect(typeSigned('', '-').text, '-');
      expect(typeSigned('-', '-5').text, '-0,05');
      expect(typeSigned('12,34', '12,34-').text, '-12,34');
    });

    test('a second "-" makes it positive again', () {
      expect(typeSigned('-12,34', '-12,34-').text, '12,34');
    });

    test('without the option the sign is dropped', () {
      expect(type('', '-5').text, '0,05');
    });
  });
}
