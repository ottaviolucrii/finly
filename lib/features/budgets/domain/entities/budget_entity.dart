import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';

/// A monthly limit for one expense category. Each change is saved as a new
/// version; the limit for a month is the latest version whose
/// [effectiveFrom] is not after it (SRS BR-15).
class BudgetEntity extends Equatable {
  final String id;
  final String workspaceId;
  final String categoryId;

  /// First day of the month this version starts to apply.
  final DateTime effectiveFrom;
  final int limitCents;
  final String currency;

  const BudgetEntity({
    required this.id,
    required this.workspaceId,
    required this.categoryId,
    required this.effectiveFrom,
    required this.limitCents,
    required this.currency,
  });

  Money get limit => Money(limitCents, currency);

  @override
  List<Object?> get props =>
      [id, workspaceId, categoryId, effectiveFrom, limitCents, currency];
}