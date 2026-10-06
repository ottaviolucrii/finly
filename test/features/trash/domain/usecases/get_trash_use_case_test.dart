import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/repositories/trash_repository.dart';
import 'package:finly/features/trash/domain/usecases/get_trash_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTrashRepository extends Mock implements TrashRepository {}

void main() {
  late MockTrashRepository repository;
  late GetTrashUseCase useCase;

  setUp(() {
    repository = MockTrashRepository();
    useCase = GetTrashUseCase(repository);
  });

  test('rejects an empty workspace id', () async {
    final result = await useCase(' ');

    expect(
      result,
      const Left<Failure, List<TrashedTransaction>>(
        ValidationFailure('invalid_workspace'),
      ),
    );
    verifyNever(() => repository.getTrash(any(), limit: any(named: 'limit')));
  });

  test('asks the repository for the first page of the trash', () async {
    when(() => repository.getTrash('w1', limit: GetTrashUseCase.limit)).thenAnswer(
      (_) async => const Right<Failure, List<TrashedTransaction>>([]),
    );

    final result = await useCase('w1');

    expect(result.isRight(), isTrue);
    verify(() => repository.getTrash('w1', limit: GetTrashUseCase.limit)).called(1);
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.getTrash(any(), limit: any(named: 'limit'))).thenAnswer(
      (_) async => const Left<Failure, List<TrashedTransaction>>(
        NetworkFailure('network_error'),
      ),
    );

    final result = await useCase('w1');

    expect(
      result,
      const Left<Failure, List<TrashedTransaction>>(NetworkFailure('network_error')),
    );
  });
}