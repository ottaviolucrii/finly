import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/assistant/presentation/amora_shortcuts.dart';
import 'package:finly/features/assistant/presentation/amora_tips.dart';
import 'package:flutter/material.dart';

/// Opens Amora's help: the tip of the day, writing a transaction in your own
/// words, and finding a place of the app.
Future<void> showAmoraSheet(
  BuildContext context, {
  required AmoraTip tip,
  required VoidCallback onWrite,
  required List<AmoraShortcut> shortcuts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AmoraSheet(tip: tip, onWrite: onWrite, shortcuts: shortcuts),
  );
}

class AmoraSheet extends StatefulWidget {
  final AmoraTip tip;
  final VoidCallback onWrite;
  final List<AmoraShortcut> shortcuts;

  const AmoraSheet({super.key, required this.tip, required this.onWrite, required this.shortcuts});

  @override
  State<AmoraSheet> createState() => _AmoraSheetState();
}

class _AmoraSheetState extends State<AmoraSheet> {
  /// Showing the search of places of the app instead of the start.
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Closes the sheet, then runs [action] (the next screen opens over Início).
  void _go(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    Widget option(IconData icon, String title, String hint, VoidCallback? onTap) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          enabled: onTap != null,
          leading: CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.10),
            foregroundColor: scheme.primary,
            child: Icon(icon, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(hint),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        );

    final header = Row(
      children: [
        AmoraAvatar(mood: _searching ? AmoraMood.thinking : widget.tip.mood, size: 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(
                  _searching ? 'Para onde vamos?' : 'Oi! Sou a Amora.',
                  style: text.titleLarge?.copyWith(fontSize: 19),
                ),
              ),
              Text(
                _searching ? 'Escreva o que você quer fazer.' : 'Como posso ajudar?',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );

    final List<Widget> body;
    if (_searching) {
      final results = searchShortcuts(widget.shortcuts, _query.text);
      body = [
        TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Ex.: pagar a fatura, metas, relatório',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: scheme.primary.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Não achei. Tente outras palavras, como "fatura", "orçamento" ou "exportar".',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final s in results.take(6)) option(s.icon, s.title, s.hint, () => _go(s.onOpen)),
      ];
    } else {
      body = [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Dica de hoje: ',
                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
                ),
                TextSpan(text: widget.tip.text),
              ],
            ),
            style: text.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        option(Icons.auto_awesome, 'Lançar escrevendo', '"gastei 50 no mercado ontem"', () => _go(widget.onWrite)),
        option(Icons.search, 'Encontrar uma função', '"como pago a fatura?"', () => setState(() => _searching = true)),
        option(Icons.insights_outlined, 'Perguntar sobre meu dinheiro', 'Em breve', null),
      ];
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 16),
            ...body,
          ],
        ),
      ),
    );
  }
}
