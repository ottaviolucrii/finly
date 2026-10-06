import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/categories/domain/usecases/create_category_use_case.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/categories/domain/usecases/set_category_archived_use_case.dart';
import 'package:finly/features/categories/domain/usecases/update_category_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late MockCategoryRepository repository;

  const category = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Mercado',
    kind: CategoryKind.expense,
    icon: 'shopping_bag',
    colorHex: '#1060E3',
    isDefault: false,
  );

  setUpAll(() => registerFallbackValue(CategoryKind.expense));

  setUp(() => repository = MockCategoryRepository());

  group('GetAllCategoriesUseCase', () {
    test('rejects an empty workspace id', () async {
      final result = await GetAllCategoriesUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, List<CategoryEntity>>(
          ValidationFailure('invalid_workspace'),
        ),
      );
      verifyNever(() => repository.getAllCategories(any()));
    });

    test('returns every category of the workspace', () async {
      when(() => repository.getAllCategories('w1')).thenAnswer(
        (_) async => const Right<Failure, List<CategoryEntity>>([category]),
      );

      final result = await GetAllCategoriesUseCase(repository)('w1');

      expect(result.isRight(), isTrue);
    });
  });

  group('CreateCategoryUseCase', () {
    CreateCategoryParams params({
      String name = 'Mercado',
      String icon = 'shopping_bag',
      String colorHex = '#1060E3',
    }) {
      return CreateCategoryParams(
        workspaceId: 'w1',
        name: name,
        kind: CategoryKind.expense,
        icon: icon,
        colorHex: colorHex,
      );
    }

    void verifyNotCalled() {
      verifyNever(() => repository.createCategory(
            workspaceId: any(named: 'workspaceId'),
            name: any(named: 'name'),
            kind: any(named: 'kind'),
            icon: any(named: 'icon'),
            colorHex: any(named: 'colorHex'),
          ));
    }

    Future<void> expectRejected(CreateCategoryParams p, String code) async {
      final result = await CreateCategoryUseCase(repository)(p);
      expect(result, Left<Failure, CategoryEntity>(ValidationFailure(code)));
      verifyNotCalled();
    }

    test('rejects an empty or too long name', () async {
      await expectRejected(params(name: '  '), 'invalid_category_name');
      await expectRejected(params(name: 'a' * 61), 'invalid_category_name');
    });

    test('rejects a missing icon', () async {
      await expectRejected(params(icon: ' '), 'invalid_icon');
    });

    test('rejects a colour that is not #RRGGBB', () async {
      await expectRejected(params(colorHex: 'blue'), 'invalid_color');
      await expectRejected(params(colorHex: '#12345'), 'invalid_color');
      await expectRejected(params(colorHex: '1060E3'), 'invalid_color');
    });

    test('trims the name and forwards to the repository', () async {
      when(() => repository.createCategory(
            workspaceId: 'w1',
            name: 'Mercado',
            kind: CategoryKind.expense,
            icon: 'shopping_bag',
            colorHex: '#1060E3',
          )).thenAnswer((_) async => const Right<Failure, CategoryEntity>(category));

      final result = await CreateCategoryUseCase(repository)(
        params(name: '  Mercado '),
      );

      expect(result, const Right<Failure, CategoryEntity>(category));
    });
  });

  group('UpdateCategoryUseCase', () {
    test('rejects a missing id, a bad name and a bad colour', () async {
      final useCase = UpdateCategoryUseCase(repository);

      expect(
        await useCase(const UpdateCategoryParams(
          categoryId: ' ',
          name: 'A',
          icon: 'home',
          colorHex: '#1060E3',
        )),
        const Left<Failure, CategoryEntity>(ValidationFailure('invalid_category')),
      );
      expect(
        await useCase(const UpdateCategoryParams(
          categoryId: 'c1',
          name: ' ',
          icon: 'home',
          colorHex: '#1060E3',
        )),
        const Left<Failure, CategoryEntity>(
          ValidationFailure('invalid_category_name'),
        ),
      );
      expect(
        await useCase(const UpdateCategoryParams(
          categoryId: 'c1',
          name: 'A',
          icon: 'home',
          colorHex: 'red',
        )),
        const Left<Failure, CategoryEntity>(ValidationFailure('invalid_color')),
      );
    });

    test('forwards a valid update to the repository', () async {
      when(() => repository.updateCategory(
            categoryId: 'c1',
            name: 'Supermercado',
            icon: 'shopping_bag',
            colorHex: '#1E7A4F',
          )).thenAnswer((_) async => const Right<Failure, CategoryEntity>(category));

      final result = await UpdateCategoryUseCase(repository)(
        const UpdateCategoryParams(
          categoryId: 'c1',
          name: ' Supermercado ',
          icon: 'shopping_bag',
          colorHex: '#1E7A4F',
        ),
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('SetCategoryArchivedUseCase', () {
    test('rejects an empty id', () async {
      final result = await SetCategoryArchivedUseCase(repository)(
        const SetCategoryArchivedParams(categoryId: ' ', archived: true),
      );

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('invalid_category')),
      );
      verifyNever(() => repository.setArchived(any(), archived: any(named: 'archived')));
    });

    test('archives and restores', () async {
      when(() => repository.setArchived('c1', archived: true))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      when(() => repository.setArchived('c1', archived: false))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      final useCase = SetCategoryArchivedUseCase(repository);

      final archived = await useCase(
        const SetCategoryArchivedParams(categoryId: 'c1', archived: true),
      );
      final restored = await useCase(
        const SetCategoryArchivedParams(categoryId: 'c1', archived: false),
      );

      expect(archived.isRight(), isTrue);
      expect(restored.isRight(), isTrue);
    });
  });
}