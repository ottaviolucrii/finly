import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionType', () {
    test('database labels match the enum in sql/00_types.sql', () {
      expect(TransactionType.income.dbValue, 'income');
      expect(TransactionType.expense.dbValue, 'expense');
      expect(TransactionType.transferIn.dbValue, 'transfer_in');
      expect(TransactionType.transferOut.dbValue, 'transfer_out');
    });

    test('every type survives a round trip', () {
      for (final type in TransactionType.values) {
        expect(TransactionType.fromDb(type.dbValue), type);
      }
    });

    test('an unknown label fails loudly', () {
      expect(() => TransactionType.fromDb('refund'), throwsArgumentError);
    });

    test('knows the direction and which types are transfers', () {
      expect(TransactionType.income.isCredit, isTrue);
      expect(TransactionType.transferIn.isCredit, isTrue);
      expect(TransactionType.expense.isCredit, isFalse);
      expect(TransactionType.transferOut.isCredit, isFalse);
      expect(TransactionType.transferIn.isTransfer, isTrue);
      expect(TransactionType.income.isTransfer, isFalse);
    });
  });

  group('TransactionStatus', () {
    test('database labels match the enum and survive a round trip', () {
      expect(TransactionStatus.pending.dbValue, 'pending');
      expect(TransactionStatus.posted.dbValue, 'posted');
      expect(TransactionStatus.failed.dbValue, 'failed');
      for (final status in TransactionStatus.values) {
        expect(TransactionStatus.fromDb(status.dbValue), status);
      }
    });

    test('an unknown label fails loudly', () {
      expect(() => TransactionStatus.fromDb('confirmed'), throwsArgumentError);
    });
  });
}