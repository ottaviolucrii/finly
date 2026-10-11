import 'package:finly/core/widgets/grouped_list.dart';
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

/// The Planejar tab: budgets, goals, the forecast and the tools to plan.
/// What a row opens is decided by [onOpen], so this widget stays simple.
class PlanHub extends StatelessWidget {
  /// The tax reserve exists only in a company workspace.
  final bool isBusiness;
  final ValueChanged<PlanDestination> onOpen;

  /// "Today", to write the month at the top; tests pass a fixed date.
  final DateTime Function()? clock;

  const PlanHub({
    super.key,
    required this.isBusiness,
    required this.onOpen,
    this.clock,
  });

  @override
  Widget build(BuildContext context) {
    final now = (clock ?? DateTime.now)();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          TabHeader(kicker: tabKickerFor(now), title: 'Planejar'),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'Planejamento',
            items: [
              GroupedItem(
                icon: Icons.pie_chart_outline,
                title: 'Orçamentos',
                subtitle: 'Quanto gastar em cada categoria no mês',
                onTap: () => onOpen(PlanDestination.budgets),
              ),
              GroupedItem(
                icon: Icons.flag_outlined,
                title: 'Metas',
                subtitle: 'Juntar para algo, com prazo',
                onTap: () => onOpen(PlanDestination.goals),
              ),
              GroupedItem(
                icon: Icons.show_chart,
                title: 'Previsão de saldo',
                subtitle: 'Como o saldo fica nos próximos dias',
                onTap: () => onOpen(PlanDestination.forecast),
              ),
              GroupedItem(
                icon: Icons.repeat,
                title: 'Recorrências',
                subtitle: 'Contas e receitas que se repetem',
                onTap: () => onOpen(PlanDestination.recurring),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'Ferramentas',
            items: [
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
      ),
    );
  }
}
