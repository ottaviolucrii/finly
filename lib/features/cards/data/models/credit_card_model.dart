import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';

class CreditCardModel extends CreditCardEntity {
  const CreditCardModel({
    required super.accountId,
    required super.workspaceId,
    required super.name,
    required super.currency,
    required super.limitCents,
    required super.closingDay,
    required super.dueDay,
    required super.usedCents,
  });

  /// [account] is a row of `accounts`, [details] the matching row of
  /// `credit_card_details`, and [balance] the matching row of the
  /// `account_balances` view.
  factory CreditCardModel.fromMaps({
    required Map<String, dynamic> account,
    required Map<String, dynamic> details,
    Map<String, dynamic>? balance,
  }) {
    final projected = balance == null
        ? 0
        : (balance['projected_balance_cents'] as num).toInt();

    return CreditCardModel(
      accountId: account['id'] as String,
      workspaceId: account['workspace_id'] as String,
      name: account['name'] as String,
      currency: account['currency'] as String,
      limitCents: (details['limit_cents'] as num).toInt(),
      closingDay: (details['closing_day'] as num).toInt(),
      dueDay: (details['due_day'] as num).toInt(),
      // Debt is a negative balance; a positive one (refunds) means no debt.
      usedCents: projected < 0 ? -projected : 0,
    );
  }
}