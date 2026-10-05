import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database labels match the enum in sql/00_types.sql', () {
    expect(AccountType.checking.dbValue, 'checking');
    expect(AccountType.savings.dbValue, 'savings');
    expect(AccountType.investment.dbValue, 'investment');
    expect(AccountType.creditCard.dbValue, 'credit_card');
  });

  test('every type survives a round trip', () {
    for (final type in AccountType.values) {
      expect(AccountType.fromDb(type.dbValue), type);
    }
  });

  test('an unknown label fails loudly', () {
    expect(() => AccountType.fromDb('wallet'), throwsArgumentError);
  });
}