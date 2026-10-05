import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finly/features/transactions/domain/usecases/confirm_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository repository;

  setUpAll(() => registerFallbackValue(TransactionStatus.posted));

  setUp(() => repository = MockTransactionRepository());

  const invalid = Left<Failure, void>(ValidationFailure('invalid_transaction'));
  const ok = Right<Failure, void>(null);

  group('ConfirmTransactionUseCase', () {
    test('rejects an empty id without calling the repository', () async {
      final result = await ConfirmTransactionUseCase(repository)(' ');

      expect(result, invalid);
      verifyNever(() => repository.updateStatus(any(), any()));
    });

    test('marks the transaction as posted', () async {
      when(() => repository.updateStatus('t1', TransactionStatus.posted))
          .thenAnswer((_) async => ok);

      final result = await ConfirmTransactionUseCase(repository)('t1');

      expect(result.isRight(), isTrue);
      verify(() => repository.updateStatus('t1', TransactionStatus.posted))
          .called(1);
    });
  });

  group('DeleteTransactionUseCase', () {
    test('rejects an empty id without calling the repository', () async {
      final result = await DeleteTransactionUseCase(repository)('');

      expect(result, invalid);
      verifyNever(() => repository.deleteTransaction(any()));
    });

    test('soft-deletes the transaction', () async {
      when(() => repository.deleteTransaction('t1'))
          .thenAnswer((_) async => ok);

      final result = await DeleteTransactionUseCase(repository)('t1');

      expect(result.isRight(), isTrue);
      verify(() => repository.deleteTransaction('t1')).called(1);
    });
  });

  group('RestoreTransactionUseCase', () {
    test('rejects an empty id without calling the repository', () async {
      final result = await RestoreTransactionUseCase(repository)(' ');

      expect(result, invalid);
      verifyNever(() => repository.restoreTransaction(any()));
    });

    test('restores the transaction', () async {
      when(() => repository.restoreTransaction('t1'))
          .thenAnswer((_) async => ok);

      final result = await RestoreTransactionUseCase(repository)('t1');

      expect(result.isRight(), isTrue);
      verify(() => repository.restoreTransaction('t1')).called(1);
    });
  });
}