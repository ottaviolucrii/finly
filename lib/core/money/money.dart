import 'package:equatable/equatable.dart';

/// An amount of money: an integer number of minor units (cents) in one
/// currency. Never a double (SRS NFR-02).
class Money extends Equatable implements Comparable<Money> {
  final int cents;
  final String currency;

  const Money(this.cents, this.currency);

  const Money.zero(this.currency) : cents = 0;

  bool get isNegative => cents < 0;
  bool get isZero => cents == 0;

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(cents + other.cents, currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(cents - other.cents, currency);
  }

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return cents.compareTo(other.cents);
  }

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
  }

  /// Brazilian format: "R$ 1.234,56", "-R$ 5,00". Pass
  /// `withSymbol: false` for "1.234,56".
  String format({bool withSymbol = true}) {
    final sign = cents < 0 ? '-' : '';
    final absolute = cents.abs();
    final whole = _group((absolute ~/ 100).toString());
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    final symbol = withSymbol ? '${symbolFor(currency)} ' : '';
    return '$sign$symbol$whole,$fraction';
  }

  static String symbolFor(String currency) {
    switch (currency) {
      case 'BRL':
        return r'R$';
      case 'USD':
        return r'US$';
      case 'EUR':
        return '€';
      default:
        return currency;
    }
  }

  static String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static final RegExp _digits = RegExp(r'^\d+$');
  static final RegExp _fraction = RegExp(r'^\d{1,2}$');
  static final RegExp _grouped = RegExp(r'^\d{1,3}(\.\d{3})+$');

  /// Reads an amount typed by a user in Brazilian format: "1.234,56",
  /// "1234,5", "12.50", "R$ 10", "-5". Returns null when it is not a valid
  /// amount. Never goes through a double.
  ///
  /// A single dot followed by 1-2 digits is a decimal point ("12.5");
  /// dots followed by groups of 3 digits are thousands ("1.234").
  static Money? tryParse(String input, String currency) {
    var text = input.replaceAll(RegExp(r'\s'), '');
    var negative = false;

    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    }
    for (final symbol in const [r'R$', r'US$', '€']) {
      if (text.startsWith(symbol)) {
        text = text.substring(symbol.length);
        break;
      }
    }
    if (!negative && text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    }
    if (text.isEmpty) return null;

    final String whole;
    var fraction = '0';

    if (text.contains(',')) {
      final parts = text.split(',');
      if (parts.length != 2) return null;
      final integerPart = parts[0];
      if (!_fraction.hasMatch(parts[1])) return null;
      if (!_digits.hasMatch(integerPart) && !_grouped.hasMatch(integerPart)) {
        return null;
      }
      whole = integerPart.replaceAll('.', '');
      fraction = parts[1];
    } else if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length == 2 &&
          _digits.hasMatch(parts[0]) &&
          _fraction.hasMatch(parts[1])) {
        whole = parts[0];
        fraction = parts[1];
      } else if (_grouped.hasMatch(text)) {
        whole = text.replaceAll('.', '');
      } else {
        return null;
      }
    } else {
      if (!_digits.hasMatch(text)) return null;
      whole = text;
    }

    if (whole.length > 13) return null;
    final cents = int.parse(whole) * 100 + int.parse(fraction.padRight(2, '0'));
    return Money(negative ? -cents : cents, currency);
  }

  @override
  List<Object?> get props => [cents, currency];
}