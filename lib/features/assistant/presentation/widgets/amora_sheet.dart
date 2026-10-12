import 'package:dartz/dartz.dart' show Either;
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/ai/presentation/ai_messages.dart';
import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/assistant/presentation/amora_shortcuts.dart';
import 'package:finly/features/assistant/presentation/amora_tips.dart';
import 'package:flutter/material.dart';

/// What Amora needs to answer questions about the person's money.
class AmoraAsk {
  final Future<Either<Failure, String>> Function(String question) ask;
  final Future<Either<Failure, bool>> Function() isEnabled;
  final Future<Either<Failure, void>> Function() enable;

  const AmoraAsk({required this.ask, required this.isEnabled, required this.enable});
}

/// Questions to tap, for whoever does not know what to ask.
const amoraExampleQuestions = [
  'Quanto gastei com Uber esse ano?',
  'Quanto gastei em cada categoria este mês?',
  'Quanto entrou e saiu no mês passado?',
  'Qual o saldo das minhas contas?',
];

/// Opens Amora's help: the tip of the day, writing a transaction in your own
/// words, finding a place of the app, and asking about your money.
Future<void> showAmoraSheet(
  BuildContext context, {
  required AmoraTip tip,
  required VoidCallback onWrite,
  required List<AmoraShortcut> shortcuts,
  AmoraAsk? ask,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AmoraSheet(tip: tip, onWrite: onWrite, shortcuts: shortcuts, ask: ask),
  );
}

class AmoraSheet extends StatefulWidget {
  final AmoraTip tip;
  final VoidCallback onWrite;
  final List<AmoraShortcut> shortcuts;
  final AmoraAsk? ask;

  const AmoraSheet({super.key, required this.tip, required this.onWrite, required this.shortcuts, this.ask});

  @override
  State<AmoraSheet> createState() => _AmoraSheetState();
}

class _AmoraSheetState extends State<AmoraSheet> {
  /// Showing the search of places of the app instead of the start.
  bool _searching = false;
  final _query = TextEditingController();

  /// Showing the questions about money; whether they are allowed (null while
  /// reading); a question being answered; the last answer or what went wrong.
  bool _asking = false;
  bool? _askAllowed;
  bool _thinking = false;
  final _question = TextEditingController();
  String? _answer;
  String? _askError;

  @override
  void dispose() {
    _query.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _openQuestions() async {
    setState(() {
      _asking = true;
      _askAllowed = null;
    });
    final result = await widget.ask!.isEnabled();
    if (!mounted) return;
    setState(() => _askAllowed = result.getOrElse(() => false));
  }

  Future<void> _allowQuestions() async {
    final result = await widget.ask!.enable();
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _askError = aiSaveFailureMessage(failure)),
      (_) => setState(() {
        _askAllowed = true;
        _askError = null;
      }),
    );
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _question.text).trim();
    if (question.isEmpty || _thinking) return;
    if (text != null) _question.text = text;
    FocusScope.of(context).unfocus();
    setState(() {
      _thinking = true;
      _answer = null;
      _askError = null;
    });
    final result = await widget.ask!.ask(question);
    if (!mounted) return;
    setState(() {
      _thinking = false;
      result.fold((failure) => _askError = aiFailureMessage(failure), (answer) => _answer = answer);
    });
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
        AmoraAvatar(
          mood: (_searching || _thinking) ? AmoraMood.thinking : (_asking ? AmoraMood.happy : widget.tip.mood),
          size: 60,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(
                  _asking ? 'Pergunte à Amora' : (_searching ? 'Para onde vamos?' : 'Oi! Sou a Amora.'),
                  style: text.titleLarge?.copyWith(fontSize: 19),
                ),
              ),
              Text(
                _asking
                    ? 'Sobre o seu dinheiro neste workspace.'
                    : (_searching ? 'Escreva o que você quer fazer.' : 'Como posso ajudar?'),
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );

    final List<Widget> body;
    if (_asking) {
      body = _questions(context);
    } else if (_searching) {
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
        option(
          Icons.insights_outlined,
          'Perguntar sobre meu dinheiro',
          widget.ask == null ? 'Em breve' : '"quanto gastei com Uber esse ano?"',
          widget.ask == null ? null : _openQuestions,
        ),
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

  /// The questions: permission first, then the field, examples and answer.
  List<Widget> _questions(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tint = scheme.primary.withValues(alpha: 0.08);

    if (_askAllowed == null) {
      return const [Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))];
    }

    if (_askAllowed == false) {
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(16)),
          child: Text(
            'Para responder, a Amora busca totais no seu Finly, como "R\$ 812,40 com Uber em 31 lançamentos", '
            'e só esses totais vão para a IA (Claude, da Anthropic). Ela nunca vê seus lançamentos um a um, e '
            'nada fica guardado. Você pode desligar em Configurações quando quiser.',
            style: text.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        if (_askError != null) ...[
          const SizedBox(height: 8),
          Text(_askError!, style: text.bodySmall?.copyWith(color: scheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _allowQuestions, child: const Text('Permitir perguntas')),
        const SizedBox(height: 4),
        TextButton(onPressed: () => setState(() => _asking = false), child: const Text('Agora não')),
      ];
    }

    return [
      TextField(
        controller: _question,
        enabled: !_thinking,
        maxLength: 300,
        minLines: 1,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _send(),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Ex.: quanto gastei com Uber esse ano?',
          filled: true,
          fillColor: tint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          suffixIcon: _thinking
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(tooltip: 'Perguntar', icon: const Icon(Icons.arrow_upward), onPressed: () => _send()),
        ),
      ),
      if (_thinking)
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 4),
          child: Text('Amora está pensando…', style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
        ),
      if (_answer != null)
        Semantics(
          liveRegion: true,
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(_answer!, style: text.bodyMedium?.copyWith(height: 1.45)),
          ),
        ),
      if (_askError != null)
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 4),
          child: Text(_askError!, style: text.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 14),
      Text('Experimente', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final example in amoraExampleQuestions)
            ActionChip(label: Text(example), onPressed: _thinking ? null : () => _send(example)),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'As despesas incluem pendentes, como compras no cartão ainda não pagas.',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    ];
  }
}
