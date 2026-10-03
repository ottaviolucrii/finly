import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:finly/features/transfers/domain/usecases/delete_transfer_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransferRepository extends Mock implements TransferRepository {}

void main() {
  late MockTransferRepository repository;
  late DeleteTransferUseCase useCase;

  setUp(() {
    repository = MockTransferRepository();
    useCase = DeleteTransferUseCase(repository);
  });

  test('rejects an empty id without calling the repository', () async {
    final result = await useCase(' ');

    expect(
      result,
      const Left<Failure, void>(ValidationFailure('invalid_transfer')),
    );
    verifyNever(() => repository.deleteTransfer(any()));
  });

  test('deletes the transfer', () async {
    when(() => repository.deleteTransfer('tr1'))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    final result = await useCase('tr1');

    expect(result.isRight(), isTrue);
    verify(() => repository.deleteTransfer('tr1')).called(1);
  });
}