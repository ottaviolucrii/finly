import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/usecases/create_category_use_case.dart';
import 'package:finly/features/categories/domain/usecases/update_category_use_case.dart';
import 'package:finly/features/categories/presentation/cubit/category_form_cubit.dart';
import 'package:finly/features/categories/presentation/cubit/category_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreate extends Mock implements CreateCategoryUseCase {}

class MockUpdate extends Mock implements UpdateCategoryUseCase {}

void main() {
  late MockCreate create;
  late MockUpdate update;

  setUpAll(() => registerFallbackValue(
        const CreateCategoryParams(
          workspaceId: 'x',
          name: 'x',
          kind: CategoryKind.expense,
          icon: 'category',
          colorHex: '#A8A8A8',
        ),
      ));

  const category = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Mercado',
    kind: CategoryKind.expense,
    icon: 'shopping_bag',
    colorHex: '#1060E3',
    isDefault: false,
  );
  const createParams = CreateCategoryParams(
    workspaceId: 'w1',
    name: 'Mercado',
    kind: CategoryKind.expense,
    icon: 'shopping_bag',
    colorHex: '#1060E3',
  );
  const updateParams = UpdateCategoryParams(
    categoryId: 'c1',
    name: 'Supermercado',
    icon: 'shopping_bag',
    colorHex: '#1E7A4F',
  );

  setUp(() {
    create = MockCreate();
    update = MockUpdate();
  });

  CategoryFormCubit buildCubit() =>
      CategoryFormCubit(create: create, update: update);

  Future<void> submitCreate(CategoryFormCubit cubit) => cubit.create(
        workspaceId: 'w1',
        name: 'Mercado',
        kind: CategoryKind.expense,
        icon: 'shopping_bag',
        colorHex: '#1060E3',
      );

  blocTest<CategoryFormCubit, CategoryFormState>(
    'create emits submitting then success',
    build: () {
      when(() => create(createParams))
          .thenAnswer((_) async => const Right<Failure, CategoryEntity>(category));
      return buildCubit();
    },
    act: submitCreate,
    expect: () => [
      const CategoryFormState(status: CategoryFormStatus.submitting),
      const CategoryFormState(status: CategoryFormStatus.success),
    ],
  );

  blocTest<CategoryFormCubit, CategoryFormState>(
    'create emits submitting then failure with the reason',
    build: () {
      when(() => create(createParams)).thenAnswer(
        (_) async => const Left<Failure, CategoryEntity>(
          ConflictFailure('already_exists'),
        ),
      );
      return buildCubit();
    },
    act: submitCreate,
    expect: () => [
      const CategoryFormState(status: CategoryFormStatus.submitting),
      const CategoryFormState(
        status: CategoryFormStatus.failure,
        failure: ConflictFailure('already_exists'),
      ),
    ],
  );

  blocTest<CategoryFormCubit, CategoryFormState>(
    'update emits submitting then success',
    build: () {
      when(() => update(updateParams))
          .thenAnswer((_) async => const Right<Failure, CategoryEntity>(category));
      return buildCubit();
    },
    act: (cubit) => cubit.update(
      categoryId: 'c1',
      name: 'Supermercado',
      icon: 'shopping_bag',
      colorHex: '#1E7A4F',
    ),
    expect: () => [
      const CategoryFormState(status: CategoryFormStatus.submitting),
      const CategoryFormState(status: CategoryFormStatus.success),
    ],
    verify: (_) => verifyNever(() => create(any())),
  );

  blocTest<CategoryFormCubit, CategoryFormState>(
    'create calls its use case once with what the form sent',
    build: () {
      when(() => create(createParams))
          .thenAnswer((_) async => const Right<Failure, CategoryEntity>(category));
      return buildCubit();
    },
    act: submitCreate,
    verify: (_) => verify(() => create(createParams)).called(1),
  );
}