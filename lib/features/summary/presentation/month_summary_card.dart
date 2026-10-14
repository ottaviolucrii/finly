import 'package:dartz/dartz.dart' show Either;
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/summary/data/summary_notifier.dart';
import 'package:finly/features/summary/data/summary_store.dart';
import 'package:finly/features/summary/domain/month_summary.dart';
import 'package:flutter/material.dart';

/// Reads the report of a month (the same one Relatório uses).
typedef SummaryLoader = Future<Either<Failure, MonthlyReport>> Function(DateTime month);

/// The summary of the month that just ended, on Início during the first 7
/// days of each month, until the person closes it. A tap opens the details.
class MonthSummaryCard extends StatefulWidget {
  final String workspaceId;
  final DateTime today;
  final SummaryLoader load;
  final SummaryStore store;
  final ValueChanged<DateTime> onOpen;

  /// When given, it is scheduled again if the person turned it on.
  final SummaryNotifier? notifier;

  const MonthSummaryCard({
    super.key,
    required this.workspaceId,
    required this.today,
    required this.load,
    required this.store,
    required this.onOpen,
    this.notifier,
  });

  @override
  State<MonthSummaryCard> createState() => _MonthSummaryCardState();
}

class _MonthSummaryCardState extends State<MonthSummaryCard> {
  MonthSummary? _summary;

  /// The month that ended: December when today is in January.
  DateTime get _month => DateTime(widget.today.year, widget.today.month - 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.notifier?.rearm());
    _load();
  }

  @override
  void didUpdateWidget(MonthSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) {
      _summary = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.today.day > 7) return;
    final month = _month;
    if (await widget.store.isDismissed(widget.workspaceId, month)) return;
    final result = await widget.load(month);
    if (!mounted) return;
    result.fold((_) {}, (report) {
      final summary = monthSummaryOf(report);
      if (summary != null && !summary.isEmpty) setState(() => _summary = summary);
    });
  }

  Future<void> _close() async {
    setState(() => _summary = null);
    await widget.store.dismiss(widget.workspaceId, _month);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onOpen(summary.month),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AmoraAvatar(mood: summary.netCents > 0 ? AmoraMood.celebrating : AmoraMood.happy, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        container: true,
                        header: true,
                        child: Text(
                          'Resumo de ${monthName(summary.month)}',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(summary.headline, style: text.bodyMedium?.copyWith(height: 1.4)),
                      const SizedBox(height: 6),
                      Text(
                        'Toque para ver o resumo',
                        style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Esconder o resumo', icon: const Icon(Icons.close), onPressed: _close),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
