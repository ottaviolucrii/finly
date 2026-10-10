import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/payment_amount.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:flutter/material.dart';

/// Lets the person choose how much to pay of an invoice (all of what is still
/// owed, or a part) and which account pays it.
class InvoicePaySheet extends StatefulWidget {
  final InvoiceEntity invoice;
  final String currency;
  final List<AccountEntity> sources;

  /// Called when the person confirms. [amountCents] is null when everything
  /// that is still owed is paid, so the invoice is settled even if it changed
  /// a moment ago.
  final void Function(String accountId, int? amountCents) onConfirm;

  const InvoicePaySheet({
    super.key,
    required this.invoice,
    required this.currency,
    required this.sources,
    required this.onConfirm,
  });

  @override
  State<InvoicePaySheet> createState() => _InvoicePaySheetState();
}

class _InvoicePaySheetState extends State<InvoicePaySheet> {
  late final TextEditingController _amount;
  String? _selected;

  Money _money(int cents) => Money(cents, widget.currency);

  @override
  void initState() {
    super.initState();
    // It starts with everything that is still owed: one tap pays the invoice.
    _amount = TextEditingController(
      text: _money(widget.invoice.remainingCents).format(withSymbol: false),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  PaymentAmountCheck get _check => checkPaymentAmount(
        _amount.text,
        currency: widget.currency,
        remainingCents: widget.invoice.remainingCents,
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final invoice = widget.invoice;
    final remaining = _money(invoice.remainingCents);
    final check = _check;
    final problem = check.problem;
    final canPay = _selected != null && check.isValid;

    final String? helper;
    if (check.isValid && check.isFull) {
      helper = 'Quita a fatura.';
    } else if (check.isValid) {
      helper = 'Depois deste pagamento falta '
          '${_money(invoice.remainingCents - check.cents!).format()}.';
    } else {
      helper = null;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pagar fatura ${monthYearLabel(invoice.referenceMonth)}',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (invoice.paidCents > 0) ...[
              Text(
                'Já pago ${_money(invoice.paidCents).format()} de '
                '${_money(invoice.totalCents).format()}',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Falta ${remaining.format()}',
              style: text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor a pagar',
                prefixText: '${Money.symbolFor(widget.currency)} ',
                errorText: problem == null ? null : paymentAmountMessage(problem, remaining),
                helperText: helper,
              ),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(
                  () => _amount.text = remaining.format(withSymbol: false),
                ),
                child: const Text('Pagar tudo'),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.sources.isEmpty)
              Text(
                'Você precisa de uma conta em ${widget.currency} (que não '
                'seja um cartão) para pagar. Crie uma em Contas.',
                textAlign: TextAlign.center,
              )
            else ...[
              Text('Pagar com', style: text.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final account in widget.sources)
                    ChoiceChip(
                      label: Text('${account.name} · ${account.postedBalance.format()}'),
                      selected: _selected == account.id,
                      onSelected: (_) => setState(() => _selected = account.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: canPay
                  ? () {
                      final accountId = _selected!;
                      // Everything owed is sent as "no amount", so the invoice is
                      // settled whatever happened since it was loaded.
                      final amount = check.isFull ? null : check.cents;
                      Navigator.of(context).pop();
                      widget.onConfirm(accountId, amount);
                    }
                  : null,
              child: Text(
                check.isValid ? 'Pagar ${_money(check.cents!).format()}' : 'Pagar',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
