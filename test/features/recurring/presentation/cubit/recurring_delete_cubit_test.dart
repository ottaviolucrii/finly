import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/domain/usecases/delete_recurring_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_delete_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_delete_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeleteRecurring extends Mock implements DeleteRecurringUseCase {}

void main() {
  late MockDeleteRecurring deleteRecurring;

  setUp(() => deleteRecurring = MockDeleteRecurring());

  blocTest<RecurringDeleteCubit, RecurringDeleteState>(
    'emits deleting then deleted',
    build: () {
      when(() => deleteRecurring('r1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return RecurringDeleteCubit(deleteRecurring);
    },
    act: (cubit) => cubit.delete('r1'),
    expect: () => [
      const RecurringDeleteState(status: RecurringDeleteStatus.deleting),
      const RecurringDeleteState(status: RecurringDeleteStatus.deleted),
    ],
  );

  blocTest<RecurringDeleteCubit, RecurringDeleteState>(
    'emits deleting then failure with the reason',
    build: () {
      when(() => deleteRecurring('r1')).thenAnswer(
        (_) async => const Left<Failure, void>(NetworkFailure('network_error')),
      );
      return RecurringDeleteCubit(deleteRecurring);
    },
    act: (cubit) => cubit.delete('r1'),
    expect: () => [
      const RecurringDeleteState(status: RecurringDeleteStatus.deleting),
      const RecurringDeleteState(
        status: RecurringDeleteStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<RecurringDeleteCubit, RecurringDeleteState>(
    'calls the use case once with the item id',
    build: () {
      when(() => deleteRecurring('r1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return RecurringDeleteCubit(deleteRecurring);
    },
    act: (cubit) => cubit.delete('r1'),
    verify: (_) => verify(() => deleteRecurring('r1')).called(1),
  );
}