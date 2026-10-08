import 'package:finly/core/utils/percent_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int? parse(String text, {int max = 10000}) => parseBps(text, maxBps: max);

  test('reads a whole number', () {
    expect(parse('6'), 600);
    expect(parse('0'), 0);
    expect(parse('100'), 10000);
  });

  test('reads a decimal comma or a decimal point', () {
    expect(parse('13,65'), 1365);
    expect(parse('13.65'), 1365);
    expect(parse('6,5'), 650);
  });

  test('one decimal is tenths and two decimals are hundredths', () {
    expect(parse('6,5'), 650);
    expect(parse('6,05'), 605);
    expect(parse('6,25'), 625);
  });

  test('ignores spaces and a percent sign', () {
    expect(parse(' 7 % '), 700);
    expect(parse('7,5%'), 750);
  });

  test('refuses an empty text, letters and a lone decimal', () {
    expect(parse(''), isNull);
    expect(parse('   '), isNull);
    expect(parse('dez'), isNull);
    expect(parse('6a'), isNull);
    expect(parse(',5'), isNull);
  });

  test('refuses more than two decimals', () {
    expect(parse('6,125'), isNull);
  });

  test('refuses a negative value', () {
    expect(parse('-5'), isNull);
  });

  test('refuses two separators', () {
    expect(parse('1,2,3'), isNull);
  });

  test('refuses what is above the maximum, and accepts the maximum itself', () {
    expect(parse('100,01'), isNull);
    expect(parse('100'), 10000);
    expect(parse('500', max: 50000), 50000);
    expect(parse('501', max: 50000), isNull);
  });

  test('refuses five digits before the separator', () {
    expect(parse('12345', max: 99999999), isNull);
  });
}
