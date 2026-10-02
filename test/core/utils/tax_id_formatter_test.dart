import 'package:finly/core/utils/tax_id_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCpf', () {
    test('formats a full CPF', () {
      expect(TaxIdInputFormatter.formatCpf('52998224725'), '529.982.247-25');
    });

    test('formats while typing', () {
      expect(TaxIdInputFormatter.formatCpf('5299'), '529.9');
      expect(TaxIdInputFormatter.formatCpf('529982247'), '529.982.247');
    });

    test('drops letters and extra digits', () {
      expect(TaxIdInputFormatter.formatCpf('52a99'), '529.9');
      expect(TaxIdInputFormatter.formatCpf('5299822472599'), '529.982.247-25');
    });
  });

  group('formatCnpj', () {
    test('formats a numeric CNPJ', () {
      expect(
        TaxIdInputFormatter.formatCnpj('11222333000181'),
        '11.222.333/0001-81',
      );
    });

    test('formats and upper-cases an alphanumeric CNPJ', () {
      expect(
        TaxIdInputFormatter.formatCnpj('12abc34501de35'),
        '12.ABC.345/01DE-35',
      );
    });

    test('accepts letters only in the first 12 positions', () {
      expect(
        TaxIdInputFormatter.formatCnpj('00000000E08GAB'),
        '00.000.000/E08G',
      );
    });

    test('ignores characters past 14', () {
      expect(
        TaxIdInputFormatter.formatCnpj('112223330001819999'),
        '11.222.333/0001-81',
      );
    });
  });

  group('TaxIdInputFormatter', () {
    test('masks a CPF as the user types', () {
      const formatter = TaxIdInputFormatter(isCnpj: false);

      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '52998224725'),
      );

      expect(result.text, '529.982.247-25');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('masks a CNPJ and keeps the cursor at the end', () {
      const formatter = TaxIdInputFormatter(isCnpj: true);

      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '00000000e08g12'),
      );

      expect(result.text, '00.000.000/E08G-12');
      expect(result.selection.baseOffset, result.text.length);
    });
  });
}