import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/summary/domain/month_summary.dart';
import 'package:finly/features/summary/presentation/month_summary_card.dart';
import 'package:flutter/material.dart';

/// The summary of a month with arrows to go to the others, up to the current
/// one (which says it is not over yet).
class MonthSummaryPage extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime today;
  final SummaryLoader load;

  /// Opens the full report, when the app has one.
  final VoidCallback? onOpenReport;

  const MonthSummaryPage({
    super.key,
    required this.initialMonth,
    required this.today,
    required this.load,
    this.onOpenReport,
  });

  @override
  State<MonthSummaryPage> createState() => _MonthSummaryPageState();
}

enum _Load { loading, ready, empty, failed }

class _MonthSummaryPageState extends State<MonthSummaryPage> {
  late DateTime _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  _Load _state = _Load.loading;
  MonthSummary? _summary;

  DateTime get _currentMonth => DateTime(widget.today.year, widget.today.month);

  bool get _isCurrent => _month == _currentMonth;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final month = _month;
    setState(() => _state = _Load.loading);
    final result = await widget.load(month);
    if (!mounted || month != _month) return;
    result.fold(
      (_) => setState(() => _state = _Load.failed),
      (report) {
        final summary = monthSummaryOf(report);
        setState(() {
          _summary = summary;
          _state = (summary == null || summary.isEmpty) ? _Load.empty : _Load.ready;
        });
      },
    );
  }

  void _go(int step) {
    setState(() => _month = DateTime(_month.year, _month.month + step));
    _fetch();
  }

  IconData _icon(SummaryLineKind kind) => switch (kind) {
        SummaryLineKind.flow => Icons.swap_vert,
        SummaryLineKind.net => Icons.savings_outlined,
        SummaryLineKind.comparison => Icons.compare_arrows,
        SummaryLineKind.rise => Icons.north_east,
        SummaryLineKind.top => Icons.pie_chart_outline,
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget arrow(IconData icon, String tooltip, VoidCallback? onPressed) => Material(
          color: scheme.surface,
          shape: const CircleBorder(),
          elevation: 1,
          child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onPressed),
        );

    final header = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          arrow(Icons.chevron_left, 'Mês anterior', () => _go(-1)),
          Text('${monthNameCapitalized(_month)} de ${_month.year}', style: text.titleLarge?.copyWith(fontSize: 17)),
          arrow(Icons.chevron_right, 'Próximo mês', _isCurrent ? null : () => _go(1)),
        ],
      ),
    );

    final Widget content;
    switch (_state) {
      case _Load.loading:
        content = const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
      case _Load.failed:
        content = Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Não consegui buscar o resumo agora.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _fetch, child: const Text('Tentar de novo')),
            ],
          ),
        );
      case _Load.empty:
        content = Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sem movimento neste mês. Quando houver lançamentos, a Amora conta como foi.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        );
      case _Load.ready:
        final summary = _summary!;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(22)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AmoraAvatar(mood: summary.netCents > 0 ? AmoraMood.celebrating : AmoraMood.happy, size: 52, ring: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      summary.headline,
                      style: const TextStyle(fontSize: 16, height: 1.4, color: AppColors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (_isCurrent)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'O mês ainda não acabou: estes são os números até agora.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < summary.lines.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: Icon(_icon(summary.lines[i].kind), color: scheme.primary),
                      title: Text(summary.lines[i].text, style: text.bodyMedium?.copyWith(height: 1.35)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Conta só o que já aconteceu, como o Relatório.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (widget.onOpenReport != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart),
                label: const Text('Ver o relatório completo'),
                onPressed: widget.onOpenReport,
              ),
            ],
          ],
        );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo do mês')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [header, content],
      ),
    );
  }
}
