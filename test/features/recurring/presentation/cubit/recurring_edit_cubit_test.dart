import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/domain/usecases/update_recurring_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_edit_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_edit_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUpdateRecurring extends Mock implements UpdateRecurringUseCase {}

void main() {
  late MockUpdateRecurring updateRecurring;

  final start = DateTime(2026, 10, 5);
  final params = UpdateRecurringParams(
    id: 'r1',
    categoryId: 'c1',
    amountCents: 130000,
    description: 'Aluguel',
    startDate: start,
  );

  setUp(() => updateRecurring = MockUpdateRecurring());

  Future<void> submit(RecurringEditCubit cubit) => cubit.submit(
        id: 'r1',
        categoryId: 'c1',
        amountCents: 130000,
        description: 'Aluguel',
        startDate: start,
      );

  blocTest<RecurringEditCubit, RecurringEditState>(
    'emits submitting then success',
    build: () {
      when(() => updateRecurring(params))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return RecurringEditCubit(updateRecurring);
    },
    act: submit,
    expect: () => [
      const RecurringEditState(status: RecurringEditStatus.submitting),
      const RecurringEditState(status: RecurringEditStatus.success),
    ],
  );

  blocTest<RecurringEditCubit, RecurringEditState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => updateRecurring(params)).thenAnswer(
        (_) async => const Left<Failure, void>(PermissionFailure('forbidden')),
      );
      return RecurringEditCubit(updateRecurring);
    },
    act: submit,
    expect: () => [
      const RecurringEditState(status: RecurringEditStatus.submitting),
      const RecurringEditState(
        status: RecurringEditStatus.failure,
        failure: PermissionFailure('forbidden'),
      ),
    ],
  );

  blocTest<RecurringEditCubit, RecurringEditState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => updateRecurring(params))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return RecurringEditCubit(updateRecurring);
    },
    act: submit,
    verify: (_) => verify(() => updateRecurring(params)).called(1),
  );
}