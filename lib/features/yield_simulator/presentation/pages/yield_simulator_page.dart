import 'package:finly/core/money/money.dart';
import 'package:finly/features/yield_simulator/domain/yield_form.dart';
import 'package:finly/features/yield_simulator/domain/yield_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How long a term is, for a person: "2 anos" or "18 meses".
String termLabel(int months) {
  if (months % 12 == 0) {
    final years = months ~/ 12;
    return years == 1 ? '1 ano' : '$years anos';
  }
  return months == 1 ? '1 mês' : '$months meses';
}

/// A calculator: how much an investment grows with a first deposit, deposits
/// every month and a constant rate. Everything is worked out on the phone, from
/// what is typed here; nothing is saved and nothing is sent.
class YieldSimulatorPage extends StatefulWidget {
  const YieldSimulatorPage({super.key});

  @override
  State<YieldSimulatorPage> createState() => _YieldSimulatorPageState();
}

class _YieldSimulatorPageState extends State<YieldSimulatorPage> {
  // Starting values, so the screen shows an example at once. The CDI changes
  // with the Selic, so the person types the current one.
  final _initial = TextEditingController(text: '10000,00');
  final _monthly = TextEditingController(text: '500,00');
  final _months = TextEditingController(text: '60');
  final _cdi = TextEditingController(text: '13,65');
  final _cdiShare = TextEditingController(text: '100');
  final _fixed = TextEditingController(text: '12');

  RateMode _mode = RateMode.cdi;
  TaxMode _tax = TaxMode.regressive;

  static const _termChips = [12, 24, 60, 120];

  @override
  void dispose() {
    for (final controller in [_initial, _monthly, _months, _cdi, _cdiShare, _fixed]) {
      controller.dispose();
    }
    super.dispose();
  }

  YieldFormParse get _parse => parseYieldForm(
        initialText: _initial.text,
        monthlyText: _monthly.text,
        monthsText: _months.text,
        mode: _mode,
        cdiText: _cdi.text,
        cdiShareText: _cdiShare.text,
        fixedText: _fixed.text,
        taxMode: _tax,
      );

  Widget _field(
    TextEditingController controller,
    String label,
    String? error, {
    String? prefix,
    String? suffix,
    bool decimal = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.,%]') : RegExp(r'[0-9]')),
      ],
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parse = _parse;
    final errors = parse.errors;
    final text = Theme.of(context).textTheme;
    final input = parse.input;

    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de rendimento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Quanto você investe', style: text.titleMedium),
          const SizedBox(height: 12),
          _field(_initial, 'Valor inicial', errors[YieldField.initial], prefix: 'R\$ '),
          const SizedBox(height: 12),
          _field(_monthly, 'Aporte mensal', errors[YieldField.monthly], prefix: 'R\$ '),
          const SizedBox(height: 12),
          _field(
            _months,
            'Prazo (meses)',
            errors[YieldField.months],
            decimal: false,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final months in _termChips)
                ChoiceChip(
                  label: Text(termLabel(months)),
                  selected: _months.text.trim() == '$months',
                  onSelected: (_) => setState(() => _months.text = '$months'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Quanto rende', style: text.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<RateMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: RateMode.cdi, label: Text('% do CDI')),
                ButtonSegment(value: RateMode.fixed, label: Text('Taxa fixa')),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => setState(() => _mode = selection.first),
            ),
          ),
          const SizedBox(height: 12),
          if (_mode == RateMode.cdi)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(_cdi, 'CDI (% ao ano)', errors[YieldField.cdi], suffix: '%'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _cdiShare,
                    '% do CDI',
                    errors[YieldField.cdiShare],
                    suffix: '%',
                  ),
                ),
              ],
            )
          else
            _field(_fixed, 'Taxa (% ao ano)', errors[YieldField.fixedRate], suffix: '%'),
          const SizedBox(height: 4),
          if (input != null)
            Text(
              'Taxa efetiva: ${ratePercentText(input.annualRateBps)} ao ano',
              style: text.bodySmall,
            )
          else if (_mode == RateMode.cdi)
            Text('Informe o CDI de hoje: ele muda com a Selic.', style: text.bodySmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Com imposto (CDB, Tesouro)'),
                selected: _tax == TaxMode.regressive,
                onSelected: (_) => setState(() => _tax = TaxMode.regressive),
              ),
              ChoiceChip(
                label: const Text('Isento (LCI, LCA, poupança)'),
                selected: _tax == TaxMode.exempt,
                onSelected: (_) => setState(() => _tax = TaxMode.exempt),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (input == null)
            _MessageCard(
              message: errors[YieldField.result] ??
                  'Preencha os campos acima para ver o resultado.',
            )
          else ...[
            _ResultCard(result: simulateYield(input)!),
            const SizedBox(height: 12),
            _YearsCard(result: simulateYield(input)!),
          ],
          const SizedBox(height: 12),
          const _NoticeCard(),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final YieldResult result;

  const _ResultCard({required this.result});

  Widget _row(BuildContext context, String label, String value, {bool strong = false}) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: strong ? text.titleSmall : text.bodyLarge)),
          Text(value, style: strong ? text.titleMedium : text.bodyLarge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final exempt = result.input.taxMode == TaxMode.exempt;
    String money(int cents) => Money(cents, 'BRL').format();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resultado em ${termLabel(result.input.months)}', style: text.titleMedium),
            const SizedBox(height: 8),
            Text('Total líquido', style: text.bodySmall),
            Text(money(result.netCents), style: text.headlineSmall),
            const SizedBox(height: 8),
            const Divider(),
            _row(context, 'Total investido', money(result.investedCents)),
            _row(context, 'Rendimento bruto', money(result.grossProfitCents)),
            _row(
              context,
              'Imposto de renda',
              exempt ? 'Isento' : money(result.taxCents),
            ),
            const Divider(),
            _row(context, 'Rendimento líquido', money(result.netProfitCents), strong: true),
          ],
        ),
      ),
    );
  }
}

class _YearsCard extends StatelessWidget {
  final YieldResult result;

  const _YearsCard({required this.result});

  /// Every full year and the last month.
  List<YieldPoint> get _rows {
    final months = result.input.months;
    return [
      for (final point in result.points)
        if (point.month > 0 && (point.month % 12 == 0 || point.month == months)) point,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String money(int cents) => Money(cents, 'BRL').format();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ano a ano', style: text.titleMedium),
            Text('Saldo antes do imposto de renda', style: text.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(flex: 2, child: Text('Prazo', style: text.labelLarge)),
                Expanded(
                  flex: 3,
                  child: Text('Investido', style: text.labelLarge, textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Saldo', style: text.labelLarge, textAlign: TextAlign.right),
                ),
              ],
            ),
            const Divider(),
            for (final point in _rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(termLabel(point.month), style: text.bodyMedium)),
                    Expanded(
                      flex: 3,
                      child: Text(
                        money(point.investedCents),
                        style: text.bodyMedium,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        money(point.balanceCents),
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  static const _lines = [
    'É uma simulação com uma taxa constante: os juros reais mudam.',
    'O CDI é o de hoje que você informou. Se a Selic mudar, o resultado muda.',
    'O imposto de renda é uma estimativa pela tabela regressiva (22,5% a 15%), calculada aporte por aporte. Não conta taxas de custódia, IOF nem inflação.',
    'Não é recomendação de investimento.',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline),
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
