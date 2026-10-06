import 'package:finly/features/transfers/presentation/exchange_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names the stronger currency, from reais to dollars', () {
    expect(
      exchangeRateLabel(
        fromCurrency: 'BRL',
        toCurrency: 'USD',
        fromCents: 50000,
        toCents: 9500,
      ),
      'Câmbio: 1 USD = 5,26 BRL',
    );
  });

  test('gives the same rate when the transfer goes the other way', () {
    expect(
      exchangeRateLabel(
        fromCurrency: 'USD',
        toCurrency: 'BRL',
        fromCents: 10000,
        toCents: 52000,
      ),
      'Câmbio: 1 USD = 5,20 BRL',
    );
  });

  test('a typo like R\$ 500 for US\$ 200 shows an odd rate', () {
    expect(
      exchangeRateLabel(
        fromCurrency: 'BRL',
        toCurrency: 'USD',
        fromCents: 50000,
        toCents: 20000,
      ),
      'Câmbio: 1 USD = 2,50 BRL',
    );
  });

  test('equal amounts mean one to one', () {
    expect(
      exchangeRateLabel(
        fromCurrency: 'BRL',
        toCurrency: 'EUR',
        fromCents: 1000,
        toCents: 1000,
      ),
      'Câmbio: 1 EUR = 1,00 BRL',
    );
  });

  test('there is no rate until both amounts are above zero', () {
    expect(
      exchangeRateLabel(
        fromCurrency: 'BRL',
        toCurrency: 'USD',
        fromCents: 0,
        toCents: 100,
      ),
      isNull,
    );
    expect(
      exchangeRateLabel(
        fromCurrency: 'BRL',
        toCurrency: 'USD',
        fromCents: 100,
        toCents: 0,
      ),
      isNull,
    );
  });
}