import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// The accounts a transaction of [type] can use. Money that comes in goes to
/// a bank account: a credit card does not receive money (an income on a card
/// would only become a credit on its invoice). Money that goes out can use
/// any account, cards included.
List<AccountEntity> accountsForType(TransactionType type, List<AccountEntity> accounts) {
  if (type != TransactionType.income) return accounts;
  return [for (final account in accounts) if (account.type != AccountType.creditCard) account];
}

/// Shown when there is no bank account for money that comes in.
const noAccountForIncome = 'Para registrar uma entrada, crie uma conta bancária. '
    'Cartão de crédito não recebe dinheiro.';
