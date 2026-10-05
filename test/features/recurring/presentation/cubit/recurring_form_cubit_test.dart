import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/usecases/create_recurring_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_form_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_form_state.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateRecurring extends Mock implements CreateRecurringUseCase {}

void main() {
  late MockCreateRecurring createRecurring;

  final start = DateTime(2026, 3, 5);
  final params = CreateRecurringParams(
    workspaceId: 'w1',
    accountId: 'a1',
    type: TransactionType.expense,
    amountCents: 120000,
    currency: 'BRL',
    description: 'Aluguel',
    frequency: RecurrenceFrequency.monthly,
    intervalCount: 1,
    startDate: start,
  );
  final created = RecurringEntity(
    id: 'r1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: null,
    type: TransactionType.expense,
    amountCents: 120000,
    currency: 'BRL',
    description: 'Aluguel',
    frequency: RecurrenceFrequency.monthly,
    intervalCount: 1,
    startDate: start,
    endDate: null,
    isActive: true,
  );

  setUp(() => createRecurring = MockCreateRecurring());

  Future<void> submit(RecurringFormCubit cubit) => cubit.submit(
        workspaceId: 'w1',
        accountId: 'a1',
        type: TransactionType.expense,
        amountCents: 120000,
        currency: 'BRL',
        description: 'Aluguel',
        frequency: RecurrenceFrequency.monthly,
        intervalCount: 1,
        startDate: start,
      );

  blocTest<RecurringFormCubit, RecurringFormState>(
    'emits submitting then success',
    build: () {
      when(() => createRecurring(params)).thenAnswer(
        (_) async => Right<Failure, RecurringEntity>(created),
      );
      return RecurringFormCubit(createRecurring);
    },
    act: submit,
    expect: () => [
      const RecurringFormState(status: RecurringFormStatus.submitting),
      const RecurringFormState(status: RecurringFormStatus.success),
    ],
  );

  blocTest<RecurringFormCubit, RecurringFormState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => createRecurring(params)).thenAnswer(
        (_) async => const Left<Failure, RecurringEntity>(
          ValidationFailure('invalid_interval'),
        ),
      );
      return RecurringFormCubit(createRecurring);
    },
    act: submit,
    expect: () => [
      const RecurringFormState(status: RecurringFormStatus.submitting),
      const RecurringFormState(
        status: RecurringFormStatus.failure,
        failure: ValidationFailure('invalid_interval'),
      ),
    ],
  );

  blocTest<RecurringFormCubit, RecurringFormState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => createRecurring(params)).thenAnswer(
        (_) async => Right<Failure, RecurringEntity>(created),
      );
      return RecurringFormCubit(createRecurring);
    },
    act: submit,
    verify: (_) => verify(() => createRecurring(params)).called(1),
  );
}