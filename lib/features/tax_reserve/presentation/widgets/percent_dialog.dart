import 'package:finly/features/tax_reserve/domain/tax_reserve_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for the percentage of the income to set aside. Returns it in basis
/// points, or null when the person cancels.
Future<int?> showPercentDialog(BuildContext context, {required int currentBps}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _PercentDialog(currentBps: currentBps),
  );
}

class _PercentDialog extends StatefulWidget {
  final int currentBps;

  const _PercentDialog({required this.currentBps});

  @override
  State<_PercentDialog> createState() => _PercentDialogState();
}

class _PercentDialogState extends State<_PercentDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentBps > 0 ? percentInput(widget.currentBps) : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final bps = parsePercentToBps(_controller.text);
    if (bps == null) {
      setState(() => _error = 'Informe um valor de 0 a 100 (ex.: 6 ou 6,5).');
      return;
    }
    Navigator.of(context).pop(bps);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quanto reservar?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A porcentagem das entradas do mês que você separa para impostos.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,%]'))],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: 'Porcentagem',
              suffixText: '%',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}
