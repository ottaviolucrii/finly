import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';

class AccountEntity extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final AccountType type;
  final String currency;
  final int openingBalanceCents;

  /// Opening balance plus posted transactions.
  final int postedBalanceCents;

  /// Posted balance plus pending transactions.
  final int projectedBalanceCents;

  const AccountEntity({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalanceCents,
    required this.postedBalanceCents,
    required this.projectedBalanceCents,
  });

  Money get postedBalance => Money(postedBalanceCents, currency);
  Money get projectedBalance => Money(projectedBalanceCents, currency);

  /// True when pending transactions would change the balance.
  bool get hasPendingEffect => projectedBalanceCents != postedBalanceCents;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        name,
        type,
        currency,
        openingBalanceCents,
        postedBalanceCents,
        projectedBalanceCents,
      ];
}