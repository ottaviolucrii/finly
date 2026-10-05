import 'package:finly/features/accounts/data/models/account_model.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const accountRow = {
    'id': 'a1',
    'workspace_id': 'w1',
    'name': 'Nubank',
    'type': 'checking',
    'currency': 'BRL',
    'opening_balance_cents': 100000,
  };

  test('combines the account row with its balance row', () {
    final model = AccountModel.fromMaps(
      account: accountRow,
      balance: const {
        'account_id': 'a1',
        'posted_balance_cents': 375000,
        'projected_balance_cents': 367000,
      },
    );

    expect(model.id, 'a1');
    expect(model.workspaceId, 'w1');
    expect(model.name, 'Nubank');
    expect(model.type, AccountType.checking);
    expect(model.currency, 'BRL');
    expect(model.openingBalanceCents, 100000);
    expect(model.postedBalanceCents, 375000);
    expect(model.projectedBalanceCents, 367000);
    expect(model.hasPendingEffect, isTrue);
  });

  test('uses the opening balance when there is no balance row', () {
    final model = AccountModel.fromMaps(account: accountRow);

    expect(model.postedBalanceCents, 100000);
    expect(model.projectedBalanceCents, 100000);
    expect(model.hasPendingEffect, isFalse);
  });

  test('reads JSON numbers (int or double) as whole cents', () {
    final model = AccountModel.fromMaps(
      account: const {
        'id': 'a2',
        'workspace_id': 'w1',
        'name': 'Poupança',
        'type': 'savings',
        'currency': 'USD',
        'opening_balance_cents': 2500.0,
      },
    );

    expect(model.openingBalanceCents, 2500);
    expect(model.type, AccountType.savings);
    expect(model.postedBalance.format(), r'US$ 25,00');
  });
}