import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// The accounts a transaction can be moved to: another account of the same
/// workspace and the same currency. An expense of a bank account can also go to
/// a credit card (it becomes a purchase on the invoice of its date); an income
/// cannot, and a card purchase can only go back to a bank account. The database
/// checks the same rules (and that the account is not archived), so this only
/// keeps the list short and sensible. Sorted by name.
List<AccountEntity> eligibleMoveTargets(
  List<AccountEntity> accounts,
  TransactionEntity transaction,
) {
  var comesFromCard = false;
  for (final account in accounts) {
    if (account.id == transaction.accountId) {
      comesFromCard = account.type == AccountType.creditCard;
    }
  }
  final cardsAllowed = transaction.type == TransactionType.expense && !comesFromCard;

  final targets = [
    for (final account in accounts)
      if (account.id != transaction.accountId &&
          account.workspaceId == transaction.workspaceId &&
          account.currency == transaction.currency &&
          (account.type != AccountType.creditCard || cardsAllowed))
        account,
  ];

  targets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return targets;
}
