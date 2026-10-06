import 'package:equatable/equatable.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// One income or expense of the month, reduced to what the totals need.
class CashFlowEntry extends Equatable {
  final TransactionType type;
  final TransactionStatus status;
  final String currency;
  final int amountCents;

  const CashFlowEntry({
    required this.type,
    required this.status,
    required this.currency,
    required this.amountCents,
  });

  @override
  List<Object?> get props => [type, status, currency, amountCents];
}