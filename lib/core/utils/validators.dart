// Tax-ID rules mirror the database functions `is_valid_cpf` and
/// `is_valid_cnpj` (sql/01_helpers.sql), so the app and the database
/// always agree.
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@([A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$',
  );
  static final RegExp _cpfShape = RegExp(r'^[0-9]{11}$');
  static final RegExp _cnpjShape = RegExp(r'^[0-9A-Z]{12}[0-9]{2}$');
  static final RegExp _repeatedDigit = RegExp(r'^(.)\1+$');

  static const List<int> _cnpjWeights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  static const List<int> _cnpjWeights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  /// Removes masks (dots, slashes, dashes, spaces) and upper-cases letters.
  /// "00.000.000/e08g-12" -> "00000000E08G12".
  static String normalizeTaxId(String value) =>
      value.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

  /// Standard e-mail format. Accepts long TLDs such as `.solutions`.
  static bool isValidEmail(String email) {
    final value = email.trim();
    if (value.isEmpty || value.length > 254 || value.contains('..')) {
      return false;
    }
    return _email.hasMatch(value);
  }

  /// At least 8 characters with at least one letter and one digit (SRS FR-A01).
  static bool isValidPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  /// 2 to 120 characters after trimming (matches the database check).
  static bool isValidFullName(String name) {
    final length = name.trim().length;
    return length >= 2 && length <= 120;
  }

  /// CPF: 11 digits, two mod-11 check digits, repeated digits rejected.
  static bool isValidCPF(String value) {
    final cpf = normalizeTaxId(value);
    if (!_cpfShape.hasMatch(cpf)) return false;
    if (_repeatedDigit.hasMatch(cpf)) return false;

    final digits = cpf.split('').map(int.parse).toList();
    return _cpfCheckDigit(digits, 9) == digits[9] &&
        _cpfCheckDigit(digits, 10) == digits[10];
  }

  static int _cpfCheckDigit(List<int> digits, int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += digits[i] * (length + 1 - i);
    }
    final remainder = (sum * 10) % 11;
    return remainder == 10 ? 0 : remainder;
  }

  /// CNPJ, numeric or alphanumeric (IN RFB 2.229/2024): 12 characters
  /// [0-9A-Z] followed by 2 numeric check digits. A character's value is its
  /// ASCII code minus 48 ('0' = 0 ... '9' = 9, 'A' = 17 ... 'Z' = 42).
  static bool isValidCNPJ(String value) {
    final cnpj = normalizeTaxId(value);
    if (!_cnpjShape.hasMatch(cnpj)) return false;
    if (_repeatedDigit.hasMatch(cnpj)) return false;

    final values = cnpj.codeUnits.map((unit) => unit - 48).toList();
    return _cnpjCheckDigit(values, _cnpjWeights1) == values[12] &&
        _cnpjCheckDigit(values, _cnpjWeights2) == values[13];
  }

  static int _cnpjCheckDigit(List<int> values, List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += values[i] * weights[i];
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }
}