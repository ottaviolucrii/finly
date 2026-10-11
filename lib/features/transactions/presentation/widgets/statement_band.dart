import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:flutter/material.dart';

const List<String> _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/// "Outubro de 2026".
String monthTitle(DateTime month) => '${_monthNames[month.month - 1]} de ${month.year}';

/// What the band says about the period.
enum StatementPeriod { month, custom, all }

/// The top of Extrato: the deep blue band with the title, the buttons, the
/// month with arrows and what came in, went out and was left that month.
class StatementBand extends StatelessWidget {
  /// The month shown, when [period] is [StatementPeriod.month].
  final DateTime month;
  final StatementPeriod period;

  /// The totals of the month; null while loading or when not a month.
  final MonthlyFlowEntry? totals;

  /// True while the totals load for the first time.
  final bool loadingTotals;

  /// Number of filters set in the sheet (the badge on the button).
  final int filterCount;
  final bool searching;

  /// Shows a back arrow (the page was opened from another screen).
  final bool showBack;

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Goes back to the current month (from a custom period or all of them).
  final VoidCallback onThisMonth;
  final VoidCallback onSearch;
  final VoidCallback onFilters;
  final VoidCallback onTransfer;
  final VoidCallback onTrash;

  const StatementBand({
    super.key,
    required this.month,
    required this.period,
    required this.totals,
    required this.loadingTotals,
    required this.filterCount,
    required this.searching,
    required this.showBack,
    required this.onPrevious,
    required this.onNext,
    required this.onThisMonth,
    required this.onSearch,
    required this.onFilters,
    required this.onTransfer,
    required this.onTrash,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(showBack ? 8 : 20, top + 8, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: 'Voltar',
                  icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              Expanded(
                child: Semantics(
                  container: true,
                  header: true,
                  child: const Text(
                    'Extrato',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 26,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              _RoundButton(
                icon: searching ? Icons.search_off : Icons.search,
                tooltip: searching ? 'Fechar busca' : 'Buscar',
                onPressed: onSearch,
              ),
              const SizedBox(width: 8),
              _RoundButton(
                icon: Icons.tune,
                tooltip: filterCount > 0 ? 'Filtros, $filterCount ativos' : 'Filtros',
                badge: filterCount,
                onPressed: onFilters,
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Mais opções',
                icon: const Icon(Icons.more_vert, color: AppColors.white),
                onSelected: (value) => value == 'transfer' ? onTransfer() : onTrash(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'transfer', child: Text('Transferir')),
                  PopupMenuItem(value: 'trash', child: Text('Lixeira')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: showBack ? 12 : 0, right: 8),
            child: period == StatementPeriod.month
                ? _MonthRow(month: month, onPrevious: onPrevious, onNext: onNext)
                : _OtherPeriodRow(period: period, onThisMonth: onThisMonth),
          ),
          if (period == StatementPeriod.month) ...[
            const SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.only(left: showBack ? 12 : 0, right: 8),
              child: _Totals(totals: totals, loading: loadingTotals),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final int badge;
  final VoidCallback onPressed;

  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          backgroundColor: AppColors.gold,
          textColor: AppColors.midnight,
          child: Icon(icon, color: AppColors.white, size: 22),
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthRow({required this.month, required this.onPrevious, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ArrowButton(icon: Icons.chevron_left, tooltip: 'Mês anterior', onPressed: onPrevious),
        Expanded(
          child: Text(
            monthTitle(month),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.white,
            ),
          ),
        ),
        _ArrowButton(icon: Icons.chevron_right, tooltip: 'Próximo mês', onPressed: onNext),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ArrowButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _OtherPeriodRow extends StatelessWidget {
  final StatementPeriod period;
  final VoidCallback onThisMonth;

  const _OtherPeriodRow({required this.period, required this.onThisMonth});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            period == StatementPeriod.all ? 'Todos os períodos' : 'Período escolhido nos filtros',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.white,
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.goldOnBand),
          onPressed: onThisMonth,
          child: const Text('Ver este mês'),
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  final MonthlyFlowEntry? totals;
  final bool loading;

  const _Totals({required this.totals, required this.loading});

  @override
  Widget build(BuildContext context) {
    final entry = totals;
    String money(int cents) => entry == null ? (loading ? '…' : 'R\$ 0,00') : Money(cents, entry.currency).format();
    final income = entry?.incomeCents ?? 0;
    final expense = entry?.expenseCents ?? 0;
    final result = income - expense;
    final resultText = entry == null && loading
        ? '…'
        : '${result < 0 ? '−' : '+'} ${Money(result.abs(), entry?.currency ?? 'BRL').format()}';

    return Row(
      children: [
        Expanded(child: _Tile(label: 'Entradas', value: money(income))),
        const SizedBox(width: 8),
        Expanded(child: _Tile(label: 'Saídas', value: money(expense), color: AppColors.goldOnBand)),
        const SizedBox(width: 8),
        Expanded(child: _Tile(label: result < 0 ? 'Faltou' : 'Sobrou', value: resultText)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Tile({required this.label, required this.value, this.color = AppColors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onBand)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
