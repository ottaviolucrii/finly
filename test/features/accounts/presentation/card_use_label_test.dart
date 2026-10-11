import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/presentation/pages/accounts_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AccountEntity card({int posted = 0, int projected = 0}) => AccountEntity(
        id: 'c1',
        workspaceId: 'w1',
        name: 'Nubank',
        type: AccountType.creditCard,
        currency: 'BRL',
        openingBalanceCents: 0,
        postedBalanceCents: posted,
        projectedBalanceCents: projected,
      );

  test('purchases still to pay with the invoice are in use', () {
    // Card purchases are pending until the invoice is paid: the confirmed
    // balance stays at zero, the expected one goes down.
    expect(cardUseLabel(card(posted: 0, projected: -184335)), 'Em uso R\$ 1.843,35');
  });

  test('a card with nothing to pay is not in use', () {
    expect(cardUseLabel(card()), 'Sem uso');
  });

  test('a card with credit (a refund bigger than the purchases) is not in use', () {
    expect(cardUseLabel(card(projected: 5000)), 'Sem uso');
  });
}
