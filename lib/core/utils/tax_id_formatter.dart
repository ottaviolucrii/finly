import 'package:flutter/services.dart';

/// Input mask for CPF (000.000.000-00) and CNPJ (00.000.000/0000-00).
/// CNPJ accepts letters in the first 12 positions (alphanumeric CNPJ).
class TaxIdInputFormatter extends TextInputFormatter {
  final bool isCnpj;

  const TaxIdInputFormatter({required this.isCnpj});

  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _letter = RegExp(r'[A-Z]');

  /// Digits only, at most 11.
  static String cleanCpf(String input) {
    final buffer = StringBuffer();
    for (final char in input.split('')) {
      if (buffer.length >= 11) break;
      if (_digit.hasMatch(char)) buffer.write(char);
    }
    return buffer.toString();
  }

  /// Digits and letters in the first 12 positions, digits in the last 2.
  static String cleanCnpj(String input) {
    final buffer = StringBuffer();
    var count = 0;
    for (final char in input.toUpperCase().split('')) {
      if (count >= 14) break;
      final isDigit = _digit.hasMatch(char);
      final isLetter = _letter.hasMatch(char);
      final accepted = count < 12 ? (isDigit || isLetter) : isDigit;
      if (accepted) {
        buffer.write(char);
        count++;
      }
    }
    return buffer.toString();
  }

  static String formatCpf(String input) {
    final clean = cleanCpf(input);
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  static String formatCnpj(String input) {
    final clean = cleanCnpj(input);
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = isCnpj ? formatCnpj(newValue.text) : formatCpf(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}