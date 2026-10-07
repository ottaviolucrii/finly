import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/move_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AccountEntity account(
    String id,
    String name, {
    AccountType type = AccountType.checking,
    String currency = 'BRL',
    String workspaceId = 'w1',
  }) {
    return AccountEntity(
      id: id,
      workspaceId: workspaceId,
      name: name,
      type: type,
      currency: currency,
      openingBalanceCents: 0,
      postedBalanceCents: 0,
      projectedBalanceCents: 0,
    );
  }

  final transaction = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: null,
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 2500,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: DateTime(2026, 10, 5, 12),
  );

  final income = TransactionEntity(
    id: 't2',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: null,
    type: TransactionType.income,
    status: TransactionStatus.posted,
    amountCents: 9000,
    currency: 'BRL',
    description: 'Venda',
    occurredAt: DateTime(2026, 10, 5, 12),
  );

  List<String> names(List<AccountEntity> list) => list.map((a) => a.name).toList();

  test('offers the other accounts of the same workspace and currency', () {
    final targets = eligibleMoveTargets(
      [account('a1', 'Nubank'), account('a2', 'Poupança'), account('a3', 'Carteira')],
      transaction,
    );

    expect(names(targets), ['Carteira', 'Poupança']);
  });

  test('never offers the account the transaction is already in', () {
    final targets = eligibleMoveTargets([account('a1', 'Nubank')], transaction);

    expect(targets, isEmpty);
  });

  test('leaves out an account in another currency', () {
    final targets = eligibleMoveTargets(
      [account('a2', 'Dólar', currency: 'USD'), account('a3', 'Real')],
      transaction,
    );

    expect(names(targets), ['Real']);
  });

  test('offers a credit card for an expense', () {
    final targets = eligibleMoveTargets(
      [account('a2', 'Cartão', type: AccountType.creditCard), account('a3', 'Conta')],
      transaction,
    );

    expect(names(targets), ['Cartão', 'Conta']);
  });

  test('leaves out a credit card for an income', () {
    final targets = eligibleMoveTargets(
      [
        account('a1', 'Nubank'),
        account('a2', 'Cartão', type: AccountType.creditCard),
        account('a3', 'Conta'),
      ],
      income,
    );

    expect(names(targets), ['Conta']);
  });

  test('a card purchase can only go back to a bank account', () {
    final purchase = TransactionEntity(
      id: 't3',
      workspaceId: 'w1',
      accountId: 'card1',
      categoryId: null,
      type: TransactionType.expense,
      status: TransactionStatus.posted,
      amountCents: 4000,
      currency: 'BRL',
      description: 'Loja',
      occurredAt: DateTime(2026, 10, 5, 12),
    );

    final targets = eligibleMoveTargets(
      [
        account('card1', 'Visa', type: AccountType.creditCard),
        account('card2', 'Master', type: AccountType.creditCard),
        account('a2', 'Conta'),
      ],
      purchase,
    );

    expect(names(targets), ['Conta']);
  });

  test('leaves out an account of another workspace', () {
    final targets = eligibleMoveTargets(
      [account('a2', 'Empresa', workspaceId: 'w2'), account('a3', 'Pessoal')],
      transaction,
    );

    expect(names(targets), ['Pessoal']);
  });

  test('keeps savings and investment accounts', () {
    final targets = eligibleMoveTargets(
      [
        account('a2', 'Reserva', type: AccountType.savings),
        account('a3', 'Ações', type: AccountType.investment),
      ],
      transaction,
    );

    expect(names(targets), ['Ações', 'Reserva']);
  });

  test('sorts by name, ignoring the case', () {
    final targets = eligibleMoveTargets(
      [account('a2', 'zebra'), account('a3', 'Banco'), account('a4', 'alfa')],
      transaction,
    );

    expect(names(targets), ['alfa', 'Banco', 'zebra']);
  });

  test('is empty when there are no accounts', () {
    expect(eligibleMoveTargets(const [], transaction), isEmpty);
  });

  test('does not change the list it is given', () {
    final accounts = [account('a3', 'Banco'), account('a2', 'Alfa')];

    eligibleMoveTargets(accounts, transaction);

    expect(accounts.first.name, 'Banco');
  });
}
