import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/widgets/workspace_title.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:finly/features/tax_reserve/domain/tax_reserve_rules.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_state.dart';
import 'package:finly/features/tax_reserve/presentation/tax_reserve_messages.dart';
import 'package:finly/features/tax_reserve/presentation/widgets/percent_dialog.dart';
import 'package:finly/features/tax_reserve/presentation/widgets/tax_categories_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const List<String> _monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "Outubro de 2026".
String taxReserveMonthTitle(DateTime month) {
  final name = _monthNames[month.month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)} de ${month.year}';
}

/// The tax reserve of one company workspace. The cubit is created for
/// [workspace], so it never shows data of another workspace.
class TaxReservePage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const TaxReservePage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<TaxReserveCubit>()..load(workspace.id)),
        BlocProvider(create: (_) => sl<TaxCategoriesCubit>()..load(workspace.id)),
      ],
      child: const TaxReserveView(extra: TaxCategoriesCard()),
    );
  }
}

/// The screen itself: it uses the [TaxReserveCubit] above it. [extra] is a card
/// shown under the numbers (the page gives it the one that marks which
/// categories are taxes).
class TaxReserveView extends StatelessWidget {
  final Widget? extra;

  const TaxReserveView({super.key, this.extra});

  Future<void> _changePercent(BuildContext context, TaxReserveData data) async {
    final cubit = context.read<TaxReserveCubit>();
    final bps = await showPercentDialog(context, currentBps: data.percentBps);
    if (bps != null && bps != data.percentBps) cubit.savePercent(bps);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaxReserveCubit, TaxReserveState>(
      listenWhen: (previous, current) =>
          current.saveFailure != null && previous.saveFailure != current.saveFailure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(taxReserveFailureMessage(state.saveFailure!))),
          );
      },
      builder: (context, state) {
        final cubit = context.read<TaxReserveCubit>();

        return Scaffold(
          appBar: AppBar(
            title: const WorkspaceTitle('Reserva para impostos', isBusiness: true),
            backgroundColor: AppColors.deepBlue,
            foregroundColor: AppColors.white,
          ),
          body: Column(
            children: [
              _MonthHeader(
                month: state.month,
                canGoNext: state.canGoNext,
                onPrevious: cubit.previousMonth,
                onNext: cubit.nextMonth,
              ),
              if (state.status == TaxReserveStatus.loading && state.data != null)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, TaxReserveState state) {
    final data = state.data;
    final cubit = context.read<TaxReserveCubit>();

    if (data == null) {
      if (state.status == TaxReserveStatus.failure && state.failure != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(taxReserveFailureMessage(state.failure!), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: cubit.reload, child: const Text('Tentar de novo')),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (!data.hasPercent)
          _SetPercentCard(
            saving: state.saving,
            onPressed: () => _changePercent(context, data),
          )
        else
          _SummaryCard(
            data: data,
            saving: state.saving,
            onChangePercent: () => _changePercent(context, data),
          ),
        if (extra != null) ...[
          const SizedBox(height: 12),
          extra!,
        ],
        const SizedBox(height: 12),
        const _ExplanationCard(),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              taxReserveMonthTitle(month),
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _SetPercentCard extends StatelessWidget {
  final bool saving;
  final VoidCallback onPressed;

  const _SetPercentCard({required this.saving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Defina quanto reservar', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Escolha a porcentagem das suas entradas que você separa para '
              'impostos. O Finly calcula, mês a mês, quanto isso dá e quanto '
              'dos impostos você já lançou.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : onPressed,
              child: const Text('Definir porcentagem'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final TaxReserveData data;
  final bool saving;
  final VoidCallback onChangePercent;

  const _SummaryCard({
    required this.data,
    required this.saving,
    required this.onChangePercent,
  });

  Widget _row(String label, int cents, {bool strong = false, Color color = AppColors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: strong ? 15 : 14,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong ? color : AppColors.onBand,
              ),
            ),
          ),
          Text(
            Money(cents, data.currency).format(),
            style: TextStyle(
              fontSize: strong ? 16 : 15,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exceeded = data.exceededCents > 0;
    // How much of the reserve the taxes of the month already took.
    final used = data.reserveCents <= 0 ? 0.0 : (data.taxCents / data.reserveCents).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
      decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reserva de ${percentText(data.percentBps)}',
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
                onPressed: saving ? null : onChangePercent,
                child: const Text('Alterar'),
              ),
            ],
          ),
          Text(
            'Valores em ${data.currency}, a moeda do workspace',
            style: const TextStyle(fontSize: 12, color: AppColors.onBand),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('A reservar', style: TextStyle(fontSize: 13, color: AppColors.onBand)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Money(data.reserveCents, data.currency).format(),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 30,
                            color: AppColors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Impostos do mês usaram ${(used * 100).round()}% da reserva',
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: used,
                          strokeWidth: 7,
                          color: exceeded ? AppColors.dangerOnDark : AppColors.gold,
                          backgroundColor: AppColors.white.withValues(alpha: 0.15),
                        ),
                        Center(
                          child: Text(
                            '${(used * 100).round()}%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                _row('Entradas do mês', data.incomeCents),
                _row('Impostos do mês', data.taxCents),
                Divider(color: AppColors.white.withValues(alpha: 0.15)),
                if (exceeded)
                  _row('Impostos acima da reserva', data.exceededCents, strong: true, color: AppColors.dangerOnDark)
                else
                  _row('Reserva disponível', data.remainingCents, strong: true, color: AppColors.goldOnBand),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard();

  static const _lines = [
    'A reserva é a porcentagem escolhida das entradas que já aconteceram no mês.',
    'Impostos do mês são as despesas das categorias marcadas como imposto (como "Impostos"), pagas ou pendentes.',
    'A reserva disponível é o que sobra da reserva depois desses impostos.',
    'É um guia para você se organizar. O imposto de verdade depende do seu regime, então confirme com o seu contador.',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Como calculamos'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in _lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(line, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
