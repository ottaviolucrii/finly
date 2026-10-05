import 'package:finly/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeTaxId', () {
    test('removes masks and upper-cases', () {
      expect(Validators.normalizeTaxId('529.982.247-25'), '52998224725');
      expect(Validators.normalizeTaxId('00.000.000/e08g-12'), '00000000E08G12');
    });
  });

  group('isValidEmail', () {
    test('accepts normal and long-TLD addresses', () {
      for (final email in [
        'ana@finly.com.br',
        'ana+tag@empresa.solutions',
        'a.b-c_d@sub.dominio.finance',
        ' ana@x.com ',
        'ANA@FINLY.COM',
      ]) {
        expect(Validators.isValidEmail(email), isTrue, reason: email);
      }
    });

    test('rejects malformed addresses', () {
      for (final email in [
        '',
        'ana@',
        '@x.com',
        'ana@x',
        'ana@x.c',
        'ana @x.com',
        'ana@@x.com',
        'ana..b@x.com',
        'ana@x..com',
        'ana@-x.com',
        'ana@x-.com',
      ]) {
        expect(Validators.isValidEmail(email), isFalse, reason: email);
      }
    });
  });

  group('isValidPassword', () {
    test('needs 8+ chars, a letter and a digit', () {
      expect(Validators.isValidPassword('abc12345'), isTrue);
      expect(Validators.isValidPassword('abc1234'), isFalse); // 7 chars
      expect(Validators.isValidPassword('abcdefgh'), isFalse); // no digit
      expect(Validators.isValidPassword('12345678'), isFalse); // no letter
    });
  });

  group('isValidFullName', () {
    test('2 to 120 characters after trim', () {
      expect(Validators.isValidFullName('Ana'), isTrue);
      expect(Validators.isValidFullName(' A '), isFalse);
      expect(Validators.isValidFullName('a' * 121), isFalse);
    });
  });

  group('isValidCPF', () {
    test('accepts valid CPFs with and without mask', () {
      expect(Validators.isValidCPF('52998224725'), isTrue);
      expect(Validators.isValidCPF('529.982.247-25'), isTrue);
      expect(Validators.isValidCPF('111.444.777-35'), isTrue);
    });

    test('rejects wrong check digit, wrong length and repeated digits', () {
      expect(Validators.isValidCPF('52998224726'), isFalse);
      expect(Validators.isValidCPF('5299822472'), isFalse);
      expect(Validators.isValidCPF('11111111111'), isFalse);
      expect(Validators.isValidCPF(''), isFalse);
    });

    test('rejects letters instead of silently dropping them', () {
      expect(Validators.isValidCPF('abc52998224725'), isFalse);
      expect(Validators.isValidCPF('529.982.247-2x'), isFalse);
    });
  });

  group('isValidCNPJ', () {
    test('accepts numeric CNPJs with and without mask', () {
      expect(Validators.isValidCNPJ('11222333000181'), isTrue);
      expect(Validators.isValidCNPJ('11.222.333/0001-81'), isTrue);
    });

    test('accepts alphanumeric CNPJs', () {
      // First alphanumeric CNPJ issued by the Receita Federal (31/07/2026).
      expect(Validators.isValidCNPJ('00.000.000/E08G-12'), isTrue);
      expect(Validators.isValidCNPJ('00000000E08G12'), isTrue);
      expect(Validators.isValidCNPJ('00.000.000/e08g-12'), isTrue);
      // Worked example from the official calculation guide: base 12ABC34501DE.
      expect(Validators.isValidCNPJ('12.ABC.345/01DE-35'), isTrue);
    });

    test('rejects wrong check digits', () {
      expect(Validators.isValidCNPJ('11.222.333/0001-82'), isFalse);
      expect(Validators.isValidCNPJ('00000000E08G13'), isFalse);
      expect(Validators.isValidCNPJ('12ABC34501DE00'), isFalse);
    });

    test('rejects repeated characters and wrong length', () {
      // 14 zeros pass the arithmetic, so the repeated-digit rule is what stops it.
      expect(Validators.isValidCNPJ('00000000000000'), isFalse);
      expect(Validators.isValidCNPJ('11111111111111'), isFalse);
      expect(Validators.isValidCNPJ('1122233300018'), isFalse);
      expect(Validators.isValidCNPJ(''), isFalse);
    });

    test('letters are not allowed in the check digits', () {
      expect(Validators.isValidCNPJ('00000000E08GAB'), isFalse);
    });
  });
}