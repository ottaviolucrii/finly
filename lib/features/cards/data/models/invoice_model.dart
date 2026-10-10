import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';

class InvoiceModel extends InvoiceEntity {
  const InvoiceModel({
    required super.id,
    required super.accountId,
    required super.referenceMonth,
    required super.periodStart,
    required super.periodEnd,
    required super.dueDate,
    required super.status,
    required super.totalCents,
    super.paidCents = 0,
  });

  /// [invoice] is a row of `credit_card_invoices`; [totalCents] and
  /// [paidCents] come from the `invoice_balances` view.
  factory InvoiceModel.fromMap(
    Map<String, dynamic> invoice, {
    int totalCents = 0,
    int paidCents = 0,
  }) {
    return InvoiceModel(
      id: invoice['id'] as String,
      accountId: invoice['account_id'] as String,
      referenceMonth: DateTime.parse(invoice['reference_month'] as String),
      periodStart: DateTime.parse(invoice['period_start'] as String),
      periodEnd: DateTime.parse(invoice['period_end'] as String),
      dueDate: DateTime.parse(invoice['due_date'] as String),
      status: InvoiceStatus.fromDb(invoice['status'] as String),
      totalCents: totalCents,
      paidCents: paidCents,
    );
  }
}