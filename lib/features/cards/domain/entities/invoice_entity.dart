import 'package:equatable/equatable.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';

class InvoiceEntity extends Equatable {
  final String id;

  /// The account id of the card this invoice belongs to.
  final String accountId;

  /// First day of the month the invoice is named after (the closing month).
  final DateTime referenceMonth;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime dueDate;
  final InvoiceStatus status;

  /// Charges minus refunds, in cents. Derived by the database.
  final int totalCents;

  const InvoiceEntity({
    required this.id,
    required this.accountId,
    required this.referenceMonth,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.status,
    required this.totalCents,
  });

  bool get isPaid => status == InvoiceStatus.paid;

  /// Something is still owed on this invoice.
  bool get needsPayment => !isPaid && totalCents > 0;

  @override
  List<Object?> get props => [
        id,
        accountId,
        referenceMonth,
        periodStart,
        periodEnd,
        dueDate,
        status,
        totalCents,
      ];
}