import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_move_repository.dart';
import 'package:finly/features/transactions/domain/usecases/move_transaction_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements TransactionMoveRepository {}

void main() {
  late MockRepository repository;
  late MoveTransactionUseCase useCase;

  setUp(() {
    repository = MockRepository();
    useCase = MoveTransactionUseCase(repository);
  });

  test('rejects an empty transaction id', () async {
    final result = await useCase(
      const MoveTransactionParams(transactionId: ' ', accountId: 'a2'),
    );

    expect(result, const Left<Failure, void>(ValidationFailure('invalid_transaction')));
    verifyNever(() => repository.moveTransaction(any(), any()));
  });

  test('rejects an empty account id', () async {
    final result = await useCase(
      const MoveTransactionParams(transactionId: 't1', accountId: ''),
    );

    expect(result, const Left<Failure, void>(ValidationFailure('invalid_account')));
    verifyNever(() => repository.moveTransaction(any(), any()));
  });

  test('forwards both ids to the repository', () async {
    when(() => repository.moveTransaction('t1', 'a2'))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    final result = await useCase(
      const MoveTransactionParams(transactionId: 't1', accountId: 'a2'),
    );

    expect(result.isRight(), isTrue);
    verify(() => repository.moveTransaction('t1', 'a2')).called(1);
  });

  test('passes a refusal of the database through unchanged', () async {
    when(() => repository.moveTransaction(any(), any())).thenAnswer(
      (_) async => const Left<Failure, void>(
        RuleFailure('a card purchase cannot be moved'),
      ),
    );

    final result = await useCase(
      const MoveTransactionParams(transactionId: 't1', accountId: 'a2'),
    );

    expect(
      result,
      const Left<Failure, void>(RuleFailure('a card purchase cannot be moved')),
    );
  });

  test('params with the same ids are equal', () {
    expect(
      const MoveTransactionParams(transactionId: 't1', accountId: 'a2'),
      const MoveTransactionParams(transactionId: 't1', accountId: 'a2'),
    );
  });
}
