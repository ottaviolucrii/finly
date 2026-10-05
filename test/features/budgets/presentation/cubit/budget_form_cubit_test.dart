import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/usecases/save_budget_use_case.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveBudget extends Mock implements SaveBudgetUseCase {}

void main() {
  late MockSaveBudget saveBudget;

  final month = DateTime(2026, 3);
  final params = SaveBudgetParams(
    workspaceId: 'w1',
    categoryId: 'c1',
    month: month,
    limitCents: 80000,
    currency: 'BRL',
  );
  final saved = BudgetEntity(
    id: 'b1',
    workspaceId: 'w1',
    categoryId: 'c1',
    effectiveFrom: month,
    limitCents: 80000,
    currency: 'BRL',
  );

  setUp(() => saveBudget = MockSaveBudget());

  Future<void> submit(BudgetFormCubit cubit) => cubit.submit(
        workspaceId: 'w1',
        categoryId: 'c1',
        month: month,
        limitCents: 80000,
        currency: 'BRL',
      );

  blocTest<BudgetFormCubit, BudgetFormState>(
    'emits submitting then success',
    build: () {
      when(() => saveBudget(params))
          .thenAnswer((_) async => Right<Failure, BudgetEntity>(saved));
      return BudgetFormCubit(saveBudget);
    },
    act: submit,
    expect: () => [
      const BudgetFormState(status: BudgetFormStatus.submitting),
      const BudgetFormState(status: BudgetFormStatus.success),
    ],
  );

  blocTest<BudgetFormCubit, BudgetFormState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => saveBudget(params)).thenAnswer(
        (_) async => const Left<Failure, BudgetEntity>(
          ValidationFailure('invalid_limit'),
        ),
      );
      return BudgetFormCubit(saveBudget);
    },
    act: submit,
    expect: () => [
      const BudgetFormState(status: BudgetFormStatus.submitting),
      const BudgetFormState(
        status: BudgetFormStatus.failure,
        failure: ValidationFailure('invalid_limit'),
      ),
    ],
  );

  blocTest<BudgetFormCubit, BudgetFormState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => saveBudget(params))
          .thenAnswer((_) async => Right<Failure, BudgetEntity>(saved));
      return BudgetFormCubit(saveBudget);
    },
    act: submit,
    verify: (_) => verify(() => saveBudget(params)).called(1),
  );
}