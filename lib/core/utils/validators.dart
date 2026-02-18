class Validators{

  /// Validates a standard email format
  static bool isValidEmail (String email){
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidCPF(String cpf) {
  final cleanCPF = cpf.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleanCPF.length != 11) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(cleanCPF)) return false;

  // First digit verification
  int sum = 0;
  for (int i = 0; i < 9; i++) {
    sum += int.parse(cleanCPF[i]) * (10 - i);
  }
  int remainder = (sum * 10) % 11;
  if (remainder == 10 || remainder == 11) remainder = 0;
  if (remainder != int.parse(cleanCPF[9])) return false;

  // Second digit verification
  sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += int.parse(cleanCPF[i]) * (11 - i);
  }
  remainder = (sum * 10) % 11;
  if (remainder == 10 || remainder == 11) remainder = 0;
  return remainder == int.parse(cleanCPF[10]);
}

  /// Validates a CNPJ using the official mathematical checksum.
  static bool isValidCNPJ(String cnpj) {
    final cleanCNPJ = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanCNPJ.length != 14) return false;
    if (RegExp(r'^(\d)\1+$').hasMatch(cleanCNPJ)) return false;

    List<int> digits = cleanCNPJ.split('').map((d) => int.parse(d)).toList();

    // First digit verification
    int calcDigit(List<int> weights, List<int> numbers) {
      int sum = 0;
      for (int i = 0; i < weights.length; i++) {
        sum += numbers[i] * weights[i];
      }
      int res = sum % 11;
      return res < 2 ? 0 : 11 - res;
    }

    if (calcDigit([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2], digits) != digits[12]) return false;
    if (calcDigit([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2], digits) != digits[13]) return false;

    return true;
  }
}