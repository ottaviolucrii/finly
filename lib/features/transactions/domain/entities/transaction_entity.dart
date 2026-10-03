import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

class TransactionEntity extends Equatable {
  final String id;
  final String workspaceId;
  final String accountId;
  final String? categoryId;
  final TransactionType type;
  final TransactionStatus status;

  /// Always positive; the [type] gives the direction.
  final int amountCents;
  final String currency;
  final String description;
  final DateTime occurredAt;

  const TransactionEntity({
    required this.id,
    required this.workspaceId,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.status,
    required this.amountCents,
    required this.currency,
    required this.description,
    required this.occurredAt,
  });

  Money get amount => Money(amountCents, currency);

  /// Positive when money comes in, negative when it goes out.
  int get signedCents => type.isCredit ? amountCents : -amountCents;

  bool get isPending => status == TransactionStatus.pending;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        accountId,
        categoryId,
        type,
        status,
        amountCents,
        currency,
        description,
        occurredAt,
      ];
}