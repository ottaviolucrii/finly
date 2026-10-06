import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/categories/domain/usecases/set_category_archived_use_case.dart';
import 'package:finly/features/categories/presentation/cubit/categories_cubit.dart';
import 'package:finly/features/categories/presentation/cubit/categories_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAll extends Mock implements GetAllCategoriesUseCase {}

class MockSetArchived extends Mock implements SetCategoryArchivedUseCase {}

void main() {
  late MockGetAll getAll;
  late MockSetArchived setArchived;

  const category = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Mercado',
    kind: CategoryKind.expense,
    icon: 'shopping_bag',
    colorHex: '#1060E3',
    isDefault: false,
  );

  setUpAll(() => registerFallbackValue(
        const SetCategoryArchivedParams(categoryId: 'x', archived: true),
      ));

  setUp(() {
    getAll = MockGetAll();
    setArchived = MockSetArchived();
    when(() => getAll('w1')).thenAnswer(
      (_) async => const Right<Failure, List<CategoryEntity>>([category]),
    );
  });

  CategoriesCubit buildCubit() =>
      CategoriesCubit(getAll: getAll, setArchived: setArchived);

  blocTest<CategoriesCubit, CategoriesState>(
    'load emits loading then every category',
    build: buildCubit,
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const CategoriesState(status: CategoriesStatus.loading),
      const CategoriesState(
        status: CategoriesStatus.loaded,
        categories: [category],
      ),
    ],
  );

  blocTest<CategoriesCubit, CategoriesState>(
    'load emits loading then failure',
    build: () {
      when(() => getAll('w1')).thenAnswer(
        (_) async => const Left<Failure, List<CategoryEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const CategoriesState(status: CategoriesStatus.loading),
      const CategoriesState(
        status: CategoriesStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<CategoriesCubit, CategoriesState>(
    'archiving a category reloads the list',
    build: () {
      when(() => setArchived(any()))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.setArchived(category, archived: true);
    },
    verify: (_) {
      verify(
        () => setArchived(
          const SetCategoryArchivedParams(categoryId: 'c1', archived: true),
        ),
      ).called(1);
      verify(() => getAll('w1')).called(2);
    },
  );

  blocTest<CategoriesCubit, CategoriesState>(
    'a refused archive keeps the list and reports the reason',
    build: () {
      when(() => setArchived(any())).thenAnswer(
        (_) async =>
            const Left<Failure, void>(PermissionFailure('forbidden')),
      );
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.setArchived(category, archived: true);
    },
    skip: 2,
    expect: () => [
      const CategoriesState(
        status: CategoriesStatus.loaded,
        categories: [category],
        actionFailure: PermissionFailure('forbidden'),
      ),
    ],
  );

  blocTest<CategoriesCubit, CategoriesState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <CategoriesState>[],
    verify: (_) => verifyNever(() => getAll(any())),
  );
}