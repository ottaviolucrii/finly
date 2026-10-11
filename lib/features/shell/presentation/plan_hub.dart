import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_state.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_state.dart';
import 'package:finly/features/goals/presentation/cubit/goals_state.dart';
import 'package:finly/features/shell/presentation/plan_cards.dart';
import 'package:flutter/material.dart';

/// The places the Planejar tab leads to.
enum PlanDestination { budgets, goals, forecast, recurring, simulator, taxReserve }

const List<String> _monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// "Outubro de 2026" for the top of a tab (it is shown in capitals).
String tabKickerFor(DateTime date) => '${_monthNames[date.month - 1]} de ${date.year}';

/// The Planejar tab: the forecast, the budgets of the month, the goals and
/// the tools to plan. What a link opens is decided by [onOpen]; the data comes
/// in the states, so this widget stays simple to test.
class PlanHub extends StatelessWidget {
  /// The tax reserve exists only in a company workspace.
  final bool isBusiness;
  final ValueChanged<PlanDestination> onOpen;

  final ForecastState forecast;
  final BudgetsState budgets;
  final GoalsState goals;

  /// Pull to refresh; null turns it off.
  final Future<void> Function()? onRefresh;

  /// "Today"; tests pass a fixed date.
  final DateTime Function()? clock;

  const PlanHub({
    super.key,
    required this.isBusiness,
    required this.onOpen,
    required this.forecast,
    required this.budgets,
    required this.goals,
    this.onRefresh,
    this.clock,
  });

  /// How many goals the tab shows (the rest are in Metas).
  static const goalsShown = 4;

  @override
  Widget build(BuildContext context) {
    final now = (clock ?? DateTime.now)();
    final text = Theme.of(context).textTheme;
    final shownGoals = goals.items.take(goalsShown).toList();

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        TabHeader(kicker: tabKickerFor(now), title: 'Planejar'),
        const SizedBox(height: 24),
        PlanForecastCard(
          forecast: forecast.forecasts.isEmpty ? null : forecast.forecasts.first,
          today: now,
          failed: forecast.status == ForecastStatus.failure,
          onOpen: () => onOpen(PlanDestination.forecast),
        ),
        const SizedBox(height: 16),
        PlanBudgetsCard(
          items: budgets.overview?.items,
          month: budgets.month,
          today: now,
          onOpen: () => onOpen(PlanDestination.budgets),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: SectionLabel('Metas')),
            TextButton(
              onPressed: () => onOpen(PlanDestination.goals),
              child: Text(goals.items.isEmpty ? 'Nova meta' : 'Ver todas'),
            ),
          ],
        ),
        if (goals.status == GoalsStatus.loading && goals.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (shownGoals.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Junte dinheiro para algo, com prazo: uma reserva, uma viagem, um curso.',
                style: text.bodyMedium,
              ),
            ),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [
              for (final goal in shownGoals)
                PlanGoalTile(goal: goal, onTap: () => onOpen(PlanDestination.goals)),
            ],
          ),
        const SizedBox(height: 24),
        GroupedSection(
          label: 'Ferramentas',
          items: [
            GroupedItem(
              icon: Icons.repeat,
              title: 'Recorrências',
              subtitle: 'Contas e receitas que se repetem',
              onTap: () => onOpen(PlanDestination.recurring),
            ),
            GroupedItem(
              icon: Icons.trending_up,
              title: 'Simulador de rendimento',
              subtitle: 'Quanto rende guardar todo mês',
              onTap: () => onOpen(PlanDestination.simulator),
            ),
            if (isBusiness)
              GroupedItem(
                icon: Icons.savings_outlined,
                title: 'Reserva de impostos',
                subtitle: 'Quanto separar das entradas da empresa',
                onTap: () => onOpen(PlanDestination.taxReserve),
              ),
          ],
        ),
      ],
    );

    final refresh = onRefresh;
    return SafeArea(
      bottom: false,
      child: refresh == null ? list : RefreshIndicator(onRefresh: refresh, child: list),
    );
  }
}
