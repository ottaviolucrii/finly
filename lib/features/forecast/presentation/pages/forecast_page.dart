import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/forecast_texts.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_cubit.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_state.dart';
import 'package:finly/features/forecast/presentation/widgets/forecast_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The balance forecast of one workspace. The cubit is created for
/// [workspace], so it never shows data of another workspace.
class ForecastPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const ForecastPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ForecastCubit>()..load(workspace.id),
      child: _ForecastView(workspace: workspace),
    );
  }
}

class _ForecastView extends StatefulWidget {
  final WorkspaceEntity workspace;

  const _ForecastView({required this.workspace});

  @override
  State<_ForecastView> createState() => _ForecastViewState();
}

class _ForecastViewState extends State<_ForecastView> {
  static const _horizons = [30, 60, 90];

  int _days = 30;
  String? _currency;

  @override
  Widget build(BuildContext context) {
    final isBusiness = widget.workspace.type == WorkspaceType.business;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsão de saldo'),
        backgroundColor: isBusiness ? AppColors.deepBlue : null,
        foregroundColor: isBusiness ? AppColors.white : null,
      ),
      body: BlocBuilder<ForecastCubit, ForecastState>(
        builder: (context, state) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, ForecastState state) {
    final cubit = context.read<ForecastCubit>();

    if (state.forecasts.isEmpty) {
      if (state.status == ForecastStatus.failure) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Não foi possível calcular a previsão. Verifique sua internet.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: cubit.reload,
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        );
      }
      if (state.status == ForecastStatus.loaded) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ainda não há dados para prever. Crie uma conta e alguns lançamentos.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    // A plain loop, to stay safe with the types of the list.
    var selected = state.forecasts.first;
    for (final item in state.forecasts) {
      if (item.currency == _currency) selected = item;
    }
    final forecast = selected.limitTo(_days);
    final today = state.today ?? DateTime.now();
    final warning = forecastWarning(forecast, today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (state.forecasts.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final item in state.forecasts)
                  ChoiceChip(
                    label: Text(item.currency),
                    selected: item.currency == selected.currency,
                    onSelected: (_) => setState(() => _currency = item.currency),
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            for (final days in _horizons)
              ChoiceChip(
                label: Text('$days dias'),
                selected: days == _days,
                onSelected: (_) => setState(() => _days = days),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (warning != null) _WarningCard(message: warning),
        _SummaryCard(forecast: forecast),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: ForecastLineChart(
              points: forecast.points,
              currency: forecast.currency,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _EventsCard(forecast: forecast),
        const SizedBox(height: 12),
        const _ExplanationCard(),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  final String message;

  const _WarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Forecast forecast;

  const _SummaryCard({required this.forecast});

  Widget _row(BuildContext context, String label, int cents, {String? note}) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money(cents, forecast.currency).format(),
                style: text.titleMedium?.copyWith(
                  color: cents < 0 ? scheme.error : null,
                ),
              ),
              if (note != null) Text(note, style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lowest = forecast.lowest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo', style: text.titleMedium),
            Text('Contas, sem os cartões de crédito', style: text.bodySmall),
            const SizedBox(height: 8),
            _row(context, 'Saldo atual', forecast.startCents),
            _row(context, forecastHorizonLabel(forecast.days), forecast.endCents),
            const Divider(),
            _row(
              context,
              'Menor saldo',
              lowest.balanceCents,
              note: 'em ${formatDateBr(lowest.date)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  static const _maxEvents = 12;

  final Forecast forecast;

  const _EventsCard({required this.forecast});

  IconData _icon(ForecastKind kind) {
    switch (kind) {
      case ForecastKind.pending:
        return Icons.receipt_long_outlined;
      case ForecastKind.recurring:
        return Icons.repeat;
      case ForecastKind.invoice:
        return Icons.credit_card;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final shown = forecast.events.take(_maxEvents).toList();
    final hidden = forecast.events.length - shown.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próximos lançamentos', style: text.titleMedium),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Text('Nenhum lançamento previsto neste período.', style: text.bodyMedium)
            else
              for (final event in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icon(event.item.kind), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              forecastEventTitle(event.item),
                              style: text.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${formatDateBr(event.item.date)} · '
                              '${forecastKindLabel(event.item.kind)}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            event.item.amountCents >= 0
                                ? '+ ${Money(event.item.amountCents, forecast.currency).format()}'
                                : Money(event.item.amountCents, forecast.currency).format(),
                            style: text.titleSmall,
                          ),
                          Text(
                            'saldo ${Money(event.balanceAfterCents, forecast.currency).format()}',
                            style: text.bodySmall?.copyWith(
                              color: event.balanceAfterCents < 0 ? scheme.error : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  hidden == 1 ? '+ 1 lançamento depois' : '+ $hidden lançamentos depois',
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard();

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
          for (final line in forecastExplanation)
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
