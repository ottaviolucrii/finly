import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';
import 'package:finly/features/trash/domain/repositories/trash_repository.dart';
import 'package:finly/features/trash/domain/usecases/get_trashed_transfers_use_case.dart';
import 'package:finly/features/trash/domain/usecases/restore_transfer_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTrashRepository extends Mock implements TrashRepository {}

void main() {
  late MockTrashRepository repository;

  setUp(() => repository = MockTrashRepository());

  group('GetTrashedTransfersUseCase', () {
    test('rejects an empty workspace id', () async {
      final result = await GetTrashedTransfersUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, List<TrashedTransfer>>(
          ValidationFailure('invalid_workspace'),
        ),
      );
      verifyNever(
        () => repository.getTrashedTransfers(any(), limit: any(named: 'limit')),
      );
    });

    test('asks the repository for the first page', () async {
      when(() => repository.getTrashedTransfers(
            'w1',
            limit: GetTrashedTransfersUseCase.limit,
          )).thenAnswer(
        (_) async => const Right<Failure, List<TrashedTransfer>>([]),
      );

      final result = await GetTrashedTransfersUseCase(repository)('w1');

      expect(result.isRight(), isTrue);
    });

    test('passes a repository failure through unchanged', () async {
      when(() => repository.getTrashedTransfers(any(), limit: any(named: 'limit')))
          .thenAnswer(
        (_) async => const Left<Failure, List<TrashedTransfer>>(
          NetworkFailure('network_error'),
        ),
      );

      final result = await GetTrashedTransfersUseCase(repository)('w1');

      expect(
        result,
        const Left<Failure, List<TrashedTransfer>>(NetworkFailure('network_error')),
      );
    });
  });

  group('RestoreTransferUseCase', () {
    test('rejects an empty transfer id', () async {
      final result = await RestoreTransferUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('invalid_transfer')),
      );
      verifyNever(() => repository.restoreTransfer(any()));
    });

    test('forwards the id to the repository', () async {
      when(() => repository.restoreTransfer('x1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await RestoreTransferUseCase(repository)('x1');

      expect(result.isRight(), isTrue);
      verify(() => repository.restoreTransfer('x1')).called(1);
    });

    test('passes a refused card payment through unchanged', () async {
      when(() => repository.restoreTransfer(any())).thenAnswer(
        (_) async => const Left<Failure, void>(
          RuleFailure('a card payment cannot be restored: pay the invoice again'),
        ),
      );

      final result = await RestoreTransferUseCase(repository)('x1');

      expect(
        result,
        const Left<Failure, void>(
          RuleFailure('a card payment cannot be restored: pay the invoice again'),
        ),
      );
    });
  });
}