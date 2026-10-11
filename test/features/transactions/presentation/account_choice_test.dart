import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/presentation/account_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AccountEntity account(String id, AccountType type) => AccountEntity(
        id: id,
        workspaceId: 'w1',
        name: id,
        type: type,
        currency: 'BRL',
        openingBalanceCents: 0,
        postedBalanceCents: 0,
        projectedBalanceCents: 0,
      );

  final checking = account('itau', AccountType.checking);
  final savings = account('poupanca', AccountType.savings);
  final card = account('cartao', AccountType.creditCard);

  test('money coming in goes only to bank accounts', () {
    expect(accountsForType(TransactionType.income, [card, checking, savings]), [checking, savings]);
  });

  test('money going out can use any account, cards included', () {
    expect(accountsForType(TransactionType.expense, [card, checking]), [card, checking]);
  });

  test('with only cards, nothing can receive money', () {
    expect(accountsForType(TransactionType.income, [card]), isEmpty);
  });
}
