import 'package:finly/core/money/money.dart';
import 'package:flutter/services.dart';

/// The most digits an amount can have (R$ 9.999.999.999,99).
const maxAmountDigits = 12;

/// The cents of what is in an amount field: only its digits count, the last
/// two being the cents ("53,50" is 5350). Zero when there are none.
int centsFromInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  final kept = digits.length > maxAmountDigits ? digits.substring(0, maxAmountDigits) : digits;
  return int.parse(kept);
}

/// "53,50" for 5350 (no currency symbol; it is shown beside the field).
String formatCentsInput(int cents) => Money(cents, 'BRL').format(withSymbol: false);

/// An amount typed like in bank apps: only digits, and the comma places
/// itself, the last two digits being the cents. Typing 5, 3, 5, 0 shows
/// "0,05", "0,53", "5,35", "53,50". A wrong format cannot be typed.
class CentsInputFormatter extends TextInputFormatter {
  const CentsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) return TextEditingValue.empty;
    if (digits.length > maxAmountDigits) return oldValue;

    final text = formatCentsInput(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
