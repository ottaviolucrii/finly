import 'package:finly/core/di/injection.dart';
import 'package:finly/features/summary/data/summary_notifier.dart';
import 'package:flutter/material.dart';

/// "Resumo do mês" in the notification settings: a notification on the 1st of
/// each month, at 9am. Hidden when the app has no notifier (tests).
class MonthlySummarySwitch extends StatefulWidget {
  const MonthlySummarySwitch({super.key});

  @override
  State<MonthlySummarySwitch> createState() => _MonthlySummarySwitchState();
}

class _MonthlySummarySwitchState extends State<MonthlySummarySwitch> {
  SummaryNotifier? _notifier;
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (sl.isRegistered<SummaryNotifier>()) {
      _notifier = sl<SummaryNotifier>();
      _notifier!.isEnabled().then((value) {
        if (mounted) setState(() => _enabled = value);
      });
    }
  }

  Future<void> _change(bool value) async {
    setState(() => _busy = true);
    final done = await _notifier!.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (done) _enabled = value;
    });
    if (!done) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Para avisar, o Finly precisa da permissão de notificações. Ative nas configurações do celular.'),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notifier == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.summarize_outlined),
          title: const Text('Resumo do mês'),
          subtitle: const Text('No dia 1 de cada mês, às 9h, um aviso com o resumo do mês que passou.'),
          value: _enabled ?? false,
          onChanged: (_enabled == null || _busy) ? null : _change,
        ),
      ],
    );
  }
}
