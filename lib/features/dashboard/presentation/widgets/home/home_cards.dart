import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_band.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';

/// Money that comes in, on a dark background.
const _positiveOnDark = Color(0xFF6FD39B);

const List<String> _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

const List<String> _monthShort = [
  'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
];

/// "Outubro" for the title of the month card.
String monthName(DateTime month) => _monthNames[month.month - 1];

/// "OUT" for the date of a row.
String monthShort(DateTime date) => _monthShort[date.month - 1];

/// A white card of Início with a title and, on the right, a link.
class HomeSection extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const HomeSection({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(title, style: text.titleLarge?.copyWith(fontSize: 17)),
                  ),
                ),
                if (actionLabel != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin bar with rounded ends, filled to [ratio] (0 to 1).
class ProgressLine extends StatelessWidget {
  final double ratio;
  final Color color;
  final double height;

  const ProgressLine({super.key, required this.ratio, required this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0),
        minHeight: height,
        color: color,
        backgroundColor: dark ? AppColors.borderDark : AppColors.track,
      ),
    );
  }
}

/// The month: what came in, what went out, what was left, and two bars to
/// compare them at a glance.
class HomeMonthCard extends StatelessWidget {
  final DateTime month;

  /// Null when nothing happened this month.
  final CurrencyFlow? flow;
  final bool hidden;
  final VoidCallback? onOpenReport;

  const HomeMonthCard({
    super.key,
    required this.month,
    required this.flow,
    required this.hidden,
    this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = flow;

    if (current == null) {
      return HomeSection(
        title: monthName(month),
        actionLabel: onOpenReport == null ? null : 'Relatório',
        onAction: onOpenReport,
        child: Text('Nenhum lançamento neste mês ainda.', style: text.bodyMedium),
      );
    }

    final income = current.incomePostedCents;
    final expense = current.expensePostedCents;
    final result = current.resultPostedCents;
    final biggest = income > expense ? income : expense;
    double bar(int cents) => biggest <= 0 ? 0.04 : (cents / biggest).clamp(0.04, 1.0);
    String amount(int cents) => maskedMoney(current.money(cents), hidden: hidden);

    final positive = result >= 0;
    final resultColor = positive ? (Theme.of(context).brightness == Brightness.dark ? _positiveOnDark : AppColors.positive) : scheme.error;

    return HomeSection(
      title: monthName(month),
      actionLabel: onOpenReport == null ? null : 'Relatório',
      onAction: onOpenReport,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entradas', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(amount(income), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Saídas', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(amount(expense), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Semantics(
                label: hidden ? 'Gráfico de entradas e saídas' : 'Entradas ${amount(income)}, saídas ${amount(expense)}',
                excludeSemantics: true,
                child: SizedBox(
                  height: 96,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Bar(fraction: bar(income), color: scheme.primary),
                      const SizedBox(width: 8),
                      _Bar(fraction: bar(expense), color: AppColors.gold),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  positive ? 'Sobrou no mês' : 'Faltou no mês',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                hidden
                    ? amount(result.abs())
                    : '${positive ? '+' : '−'} ${current.money(result.abs()).format()}',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: resultColor),
              ),
            ],
          ),
          if (current.hasPending && !hidden) ...[
            const SizedBox(height: 8),
            Text(
              'Ainda previsto: + ${current.money(current.incomePendingCents).format()} entrando, '
              '− ${current.money(current.expensePendingCents).format()} saindo.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;

  const _Bar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 96 * fraction,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    );
  }
}

/// The credit cards: how much of each limit is in use, and when it closes and
/// is due.
class HomeCreditCardsCard extends StatelessWidget {
  final List<CreditCardEntity> cards;
  final VoidCallback onOpen;

  const HomeCreditCardsCard({super.key, required this.cards, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shown = cards.take(2).toList();

    return HomeSection(
      title: cards.length == 1 ? 'Cartão' : 'Cartões',
      actionLabel: 'Ver faturas',
      onAction: onOpen,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 30,
                  decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(6)),
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 10,
                    height: 7,
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shown[i].name, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text(
                        'Fecha dia ${shown[i].closingDay} · vence dia ${shown[i].dueDay}',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(shown[i].used.format(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            ProgressLine(
              ratio: shown[i].usageRatio,
              color: shown[i].isOverLimit ? scheme.error : AppColors.gold,
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                shown[i].isOverLimit
                    ? 'Passou do limite de ${shown[i].limit.format()}'
                    : 'Livre ${shown[i].available.format()} de ${shown[i].limit.format()}',
                style: text.bodySmall?.copyWith(
                  color: shown[i].isOverLimit ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight: shown[i].isOverLimit ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
          if (cards.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '+ ${cards.length - shown.length} ${cards.length - shown.length == 1 ? 'cartão' : 'cartões'}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// The budgets closest to their limit.
class HomeBudgetsCard extends StatelessWidget {
  final List<BudgetProgress> budgets;
  final VoidCallback onOpen;

  const HomeBudgetsCard({super.key, required this.budgets, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return HomeSection(
      title: 'Orçamentos',
      actionLabel: 'Ver todos',
      onAction: onOpen,
      child: Column(
        children: [
          for (var i = 0; i < budgets.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(budgets[i].category.name, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ),
                Text(
                  budgets[i].level == BudgetLevel.over
                      ? '${budgets[i].spent.format()} de ${budgets[i].limit.format()} · passou'
                      : '${budgets[i].spent.format()} de ${budgets[i].limit.format()}',
                  style: text.bodySmall?.copyWith(
                    color: budgets[i].level == BudgetLevel.over ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: budgets[i].level == BudgetLevel.over ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressLine(
              ratio: budgets[i].ratio,
              color: switch (budgets[i].level) {
                BudgetLevel.over => scheme.error,
                BudgetLevel.warning => AppColors.gold,
                BudgetLevel.normal => scheme.primary,
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// What is still pending: from the last days and the next two weeks.
class HomeUpcomingCard extends StatelessWidget {
  final List<TransactionEntity> items;
  final DateTime now;
  final VoidCallback onOpen;

  const HomeUpcomingCard({super.key, required this.items, required this.now, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shown = items.take(5).toList();
    final today = DateTime(now.year, now.month, now.day);

    return HomeSection(
      title: 'Próximos lançamentos',
      actionLabel: 'Ver todos',
      onAction: onOpen,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: dark ? AppColors.blueTintDark : AppColors.blueTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(monthShort(shown[i].occurredAt.toLocal()), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.primary)),
                        Text('${shown[i].occurredAt.toLocal().day}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shown[i].description, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        Text(
                          _when(shown[i].occurredAt.toLocal(), today),
                          style: text.bodySmall?.copyWith(
                            color: _isLate(shown[i].occurredAt.toLocal(), today) ? scheme.error : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    transactionAmountText(shown[i]),
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: shown[i].type.isCredit ? (dark ? _positiveOnDark : AppColors.positive) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (items.length > shown.length)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '+ ${items.length - shown.length} mais',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  static bool _isLate(DateTime date, DateTime today) =>
      DateTime(date.year, date.month, date.day).isBefore(today);

  static String _when(DateTime date, DateTime today) {
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;
    if (diff < 0) return 'Atrasado · era ${formatDateBr(date)}';
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    return 'Em $diff dias';
  }
}

/// One goal: how much of it is saved, and what to put aside each month.
class HomeGoalCard extends StatelessWidget {
  final GoalProgress goal;
  final DateTime today;
  final VoidCallback onOpen;

  const HomeGoalCard({super.key, required this.goal, required this.today, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final currency = goal.goal.currency;
    final monthly = goal.monthlyNeededAt(today);

    final String detail;
    if (goal.achieved) {
      detail = 'Meta alcançada';
    } else if (monthly != null) {
      detail = '${Money(goal.savedCents, currency).format()} de ${Money(goal.goal.targetCents, currency).format()} · '
          '${Money(monthly, currency).format()} por mês';
    } else {
      detail = '${Money(goal.savedCents, currency).format()} de ${Money(goal.goal.targetCents, currency).format()}';
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: goal.percent / 100,
                      strokeWidth: 7,
                      color: AppColors.gold,
                      backgroundColor: dark ? AppColors.borderDark : AppColors.track,
                    ),
                    Center(
                      child: Text('${goal.percent}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.goal.name, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    Text(detail, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
