import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/assistant/presentation/getting_started.dart';
import 'package:flutter/material.dart';

/// "Primeiros passos" on Início: Amora's short guide for a new workspace.
/// Each step ticks itself when done; steps that do not apply can be skipped;
/// the whole guide can be closed. When everything is done, she celebrates.
class GettingStartedCard extends StatefulWidget {
  final String workspaceId;
  final Set<StartStep> done;

  /// False while Início is still reading: nothing is decided until then.
  final bool ready;
  final GettingStartedStore store;
  final ValueChanged<StartStep> onOpen;

  const GettingStartedCard({
    super.key,
    required this.workspaceId,
    required this.done,
    required this.ready,
    required this.store,
    required this.onOpen,
  });

  @override
  State<GettingStartedCard> createState() => _GettingStartedCardState();
}

class _GettingStartedCardState extends State<GettingStartedCard> {
  bool? _hidden;
  Set<StartStep> _skipped = const {};

  /// Seen with something still to do in this visit: only then does a finished
  /// guide celebrate (a workspace already set up just never shows it).
  bool _sawIncomplete = false;

  @override
  void initState() {
    super.initState();
    GettingStartedStore.changes.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(GettingStartedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) _load();
  }

  @override
  void dispose() {
    GettingStartedStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final hidden = await widget.store.isHidden(widget.workspaceId);
    final skipped = await widget.store.skipped(widget.workspaceId);
    if (!mounted) return;
    setState(() {
      _hidden = hidden;
      _skipped = skipped;
    });
  }

  Future<void> _hide({bool tellHowToBringBack = true}) async {
    setState(() => _hidden = true);
    await widget.store.setHidden(widget.workspaceId, true);
    if (!mounted || !tellHowToBringBack) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Guia escondido. Para ver de novo: toque na Amora → Encontrar uma função → Primeiros passos.'),
      ));
  }

  /// The ✕ of a guide still in progress asks first.
  Future<void> _confirmHide() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pular o guia?'),
        content: const Text('Você pode trazer de volta depois: toque na Amora → Encontrar uma função → Primeiros passos.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Continuar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Pular')),
        ],
      ),
    );
    if (sure == true && mounted) await _hide(tellHowToBringBack: false);
  }

  Future<void> _skip(StartStep step) async {
    setState(() => _skipped = {..._skipped, step});
    await widget.store.skip(widget.workspaceId, step);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden != false || !widget.ready) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finished = {...widget.done, ..._skipped};
    final count = StartStep.values.where(finished.contains).length;
    final all = count == StartStep.values.length;
    if (!all) {
      _sawIncomplete = true;
    } else if (!_sawIncomplete) {
      // Everything was already done: hide it quietly, no guide to show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hidden == false) _hide(tellHowToBringBack: false);
      });
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AmoraAvatar(mood: all ? AmoraMood.celebrating : AmoraMood.happy, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        container: true,
                        header: true,
                        child: Text(
                          all ? 'Tudo pronto!' : 'Primeiros passos',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        all ? 'Você já sabe usar o Finly. Muito bem!' : '$count de ${StartStep.values.length} · a Amora te ajuda a começar',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: all ? 'Fechar' : 'Pular o guia',
                  icon: const Icon(Icons.close),
                  onPressed: all ? () => _hide(tellHowToBringBack: false) : _confirmHide,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 8, bottom: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: count / StartStep.values.length,
                  minHeight: 6,
                  semanticsLabel: '$count de ${StartStep.values.length} passos',
                ),
              ),
            ),
            if (!all)
              for (final step in StartStep.values)
                _StepRow(
                  step: step,
                  done: widget.done.contains(step),
                  skipped: !widget.done.contains(step) && _skipped.contains(step),
                  onOpen: () => widget.onOpen(step),
                  onSkip: step.skipLabel == null ? null : () => _skip(step),
                ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final StartStep step;
  final bool done;
  final bool skipped;
  final VoidCallback onOpen;
  final VoidCallback? onSkip;

  const _StepRow({
    required this.step,
    required this.done,
    required this.skipped,
    required this.onOpen,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finished = done || skipped;

    return InkWell(
      onTap: finished ? null : onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : (skipped ? Icons.remove_circle_outline : Icons.radio_button_unchecked),
              color: done ? scheme.primary : scheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: finished ? TextDecoration.lineThrough : null,
                      color: finished ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  if (!finished)
                    Text(step.hint, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (!finished && onSkip != null)
              TextButton(onPressed: onSkip, child: Text(step.skipLabel!))
            else if (!finished)
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
