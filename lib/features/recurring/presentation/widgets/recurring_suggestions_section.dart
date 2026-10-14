import 'package:finly/core/money/money.dart';
import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/recurring/data/recurring_suggestion_source.dart';
import 'package:finly/features/recurring/domain/entities/recurring_suggestion.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';

String _brl(RecurringSuggestion suggestion) => 'BRL';

/// "A Amora notou": things that come back every month in the history, with a
/// way to make each one a recurring item, or to say "Agora não". Shows
/// nothing when there is nothing to suggest.
class RecurringSuggestionsSection extends StatefulWidget {
  final String workspaceId;
  final RecurringSuggestionSource source;

  /// The currency of a suggestion (the one of its account).
  final String Function(RecurringSuggestion suggestion) currencyOf;

  /// Opens the form with the suggestion filled in; true when it was created.
  final Future<bool> Function(RecurringSuggestion suggestion) onCreate;

  const RecurringSuggestionsSection({
    super.key,
    required this.workspaceId,
    required this.source,
    required this.onCreate,
    this.currencyOf = _brl,
  });

  @override
  State<RecurringSuggestionsSection> createState() => _RecurringSuggestionsSectionState();
}

class _RecurringSuggestionsSectionState extends State<RecurringSuggestionsSection> {
  static const _maxShown = 3;

  List<RecurringSuggestion> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RecurringSuggestionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) _load();
  }

  Future<void> _load() async {
    final all = await widget.source.suggestions(widget.workspaceId);
    final closed = await widget.source.dismissed(widget.workspaceId);
    if (!mounted) return;
    setState(() => _items = [for (final s in all) if (!closed.contains(s.key)) s]);
  }

  void _remove(RecurringSuggestion suggestion) => setState(() => _items = [for (final s in _items) if (s != suggestion) s]);

  Future<void> _create(RecurringSuggestion suggestion) async {
    final created = await widget.onCreate(suggestion);
    if (created && mounted) _remove(suggestion);
  }

  Future<void> _notNow(RecurringSuggestion suggestion) async {
    _remove(suggestion);
    await widget.source.dismiss(widget.workspaceId, suggestion);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final shown = _items.take(_maxShown).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AmoraAvatar(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          container: true,
                          header: true,
                          child: Text('A Amora notou', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Text(
                          'Isto se repete todo mês. Quer criar uma recorrência?',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              for (final s in shown) ...[
                const Divider(height: 24),
                Text(s.description, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${s.type == TransactionType.income ? 'Entrada' : 'Saída'} de '
                  '${Money(s.amountCents, widget.currencyOf(s)).format()} · perto do dia ${s.dayOfMonth} · '
                  'vista em ${s.monthsSeen} meses',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                // a Wrap, not a Row: with a larger text size the second button
                // goes to the next line instead of off the screen
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => _create(s),
                      child: const Text('Criar recorrência'),
                    ),
                    TextButton(onPressed: () => _notNow(s), child: const Text('Agora não')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
