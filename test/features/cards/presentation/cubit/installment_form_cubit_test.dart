import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/usecases/create_installments_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/installment_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/installment_form_state.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetCategories extends Mock implements GetCategoriesUseCase {}

class MockCreateInstallments extends Mock implements CreateInstallmentsUseCase {}

void main() {
  late MockGetCategories getCategories;
  late MockCreateInstallments createInstallments;

  final purchaseAt = DateTime(2026, 3, 5, 12);
  final params = CreateInstallmentsParams(
    accountId: 'a1',
    categoryId: 'c1',
    totalCents: 100001,
    installments: 3,
    description: 'TV',
    purchaseAt: purchaseAt,
  );

  const expense = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Compras',
    kind: CategoryKind.expense,
    icon: 'shopping_bag',
    colorHex: '#C2569B',
    isDefault: true,
  );
  const income = CategoryEntity(
    id: 'c2',
    workspaceId: 'w1',
    name: 'Vendas',
    kind: CategoryKind.income,
    icon: 'sell',
    colorHex: '#1060E3',
    isDefault: true,
  );

  setUp(() {
    getCategories = MockGetCategories();
    createInstallments = MockCreateInstallments();
  });

  InstallmentFormCubit buildCubit() => InstallmentFormCubit(
        getCategories: getCategories,
        createInstallments: createInstallments,
      );

  Future<void> submit(InstallmentFormCubit cubit) => cubit.submit(
        accountId: 'a1',
        categoryId: 'c1',
        totalCents: 100001,
        installments: 3,
        description: 'TV',
        purchaseAt: purchaseAt,
      );

  blocTest<InstallmentFormCubit, InstallmentFormState>(
    'loads only the expense categories',
    build: () {
      when(() => getCategories('w1')).thenAnswer(
        (_) async =>
            const Right<Failure, List<CategoryEntity>>([expense, income]),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.loadCategories('w1'),
    expect: () => [
      const InstallmentFormState(status: InstallmentFormStatus.loading),
      const InstallmentFormState(
        status: InstallmentFormStatus.ready,
        categories: [expense],
      ),
    ],
  );

  blocTest<InstallmentFormCubit, InstallmentFormState>(
    'reports when the categories cannot be loaded',
    build: () {
      when(() => getCategories('w1')).thenAnswer(
        (_) async => const Left<Failure, List<CategoryEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.loadCategories('w1'),
    expect: () => [
      const InstallmentFormState(status: InstallmentFormStatus.loading),
      const InstallmentFormState(
        status: InstallmentFormStatus.loadFailed,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<InstallmentFormCubit, InstallmentFormState>(
    'submit emits submitting then success and keeps the categories',
    build: () {
      when(() => createInstallments(params))
          .thenAnswer((_) async => const Right<Failure, String>('g1'));
      return buildCubit();
    },
    seed: () => const InstallmentFormState(
      status: InstallmentFormStatus.ready,
      categories: [expense],
    ),
    act: submit,
    expect: () => [
      const InstallmentFormState(
        status: InstallmentFormStatus.submitting,
        categories: [expense],
      ),
      const InstallmentFormState(
        status: InstallmentFormStatus.success,
        categories: [expense],
      ),
    ],
  );

  blocTest<InstallmentFormCubit, InstallmentFormState>(
    'submit emits submitting then failure with the reason',
    build: () {
      when(() => createInstallments(params)).thenAnswer(
        (_) async => const Left<Failure, String>(
          ValidationFailure('invalid_installments'),
        ),
      );
      return buildCubit();
    },
    seed: () => const InstallmentFormState(status: InstallmentFormStatus.ready),
    act: submit,
    expect: () => [
      const InstallmentFormState(status: InstallmentFormStatus.submitting),
      const InstallmentFormState(
        status: InstallmentFormStatus.failure,
        failure: ValidationFailure('invalid_installments'),
      ),
    ],
  );

  blocTest<InstallmentFormCubit, InstallmentFormState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => createInstallments(params))
          .thenAnswer((_) async => const Right<Failure, String>('g1'));
      return buildCubit();
    },
    seed: () => const InstallmentFormState(status: InstallmentFormStatus.ready),
    act: submit,
    verify: (_) => verify(() => createInstallments(params)).called(1),
  );
}