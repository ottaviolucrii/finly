import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';

class AccountModel extends AccountEntity {
  const AccountModel({
    required super.id,
    required super.workspaceId,
    required super.name,
    required super.type,
    required super.currency,
    required super.openingBalanceCents,
    required super.postedBalanceCents,
    required super.projectedBalanceCents,
  });

  /// [account] is a row of `accounts`; [balance] is the matching row of the
  /// `account_balances` view. Without it (for example right after creating
  /// the account) both balances equal the opening balance.
  factory AccountModel.fromMaps({
    required Map<String, dynamic> account,
    Map<String, dynamic>? balance,
  }) {
    final opening = (account['opening_balance_cents'] as num).toInt();

    return AccountModel(
      id: account['id'] as String,
      workspaceId: account['workspace_id'] as String,
      name: account['name'] as String,
      type: AccountType.fromDb(account['type'] as String),
      currency: account['currency'] as String,
      openingBalanceCents: opening,
      postedBalanceCents: balance == null
          ? opening
          : (balance['posted_balance_cents'] as num).toInt(),
      projectedBalanceCents: balance == null
          ? opening
          : (balance['projected_balance_cents'] as num).toInt(),
    );
  }
}