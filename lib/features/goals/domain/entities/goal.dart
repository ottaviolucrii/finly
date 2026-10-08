import 'package:equatable/equatable.dart';

/// A savings goal: reach [targetCents] in the account [accountId], maybe by a
/// date. The progress is the balance of that account.
class Goal extends Equatable {
  final String id;
  final String workspaceId;
  final String accountId;
  final String currency;
  final String name;
  final int targetCents;

  /// The day the person wants to have it by (date only), if any.
  final DateTime? targetDate;

  const Goal({
    required this.id,
    required this.workspaceId,
    required this.accountId,
    required this.currency,
    required this.name,
    required this.targetCents,
    this.targetDate,
  });

  @override
  List<Object?> get props => [id, workspaceId, accountId, currency, name, targetCents, targetDate];
}
