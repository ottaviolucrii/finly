import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database labels match the enum in sql/00_types.sql', () {
    expect(TransferKind.internal.dbValue, 'internal');
    expect(TransferKind.ownerWithdrawal.dbValue, 'owner_withdrawal');
    expect(TransferKind.ownerContribution.dbValue, 'owner_contribution');
  });

  test('every kind survives a round trip', () {
    for (final kind in TransferKind.values) {
      expect(TransferKind.fromDb(kind.dbValue), kind);
    }
  });

  test('an unknown label fails loudly', () {
    expect(() => TransferKind.fromDb('swap'), throwsArgumentError);
  });

  test('only owner transfers cross workspaces', () {
    expect(TransferKind.internal.crossesWorkspaces, isFalse);
    expect(TransferKind.ownerWithdrawal.crossesWorkspaces, isTrue);
    expect(TransferKind.ownerContribution.crossesWorkspaces, isTrue);
  });
}