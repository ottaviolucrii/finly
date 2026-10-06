import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/data/datasources/category_remote_data_source.dart';
import 'package:finly/features/categories/data/models/category_model.dart';
import 'package:finly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements CategoryRemoteDataSource {}

void main() {
  late MockRemote remote;
  late CategoryRepositoryImpl repository;

  const model = CategoryModel(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Mercado',
    kind: CategoryKind.expense,
    icon: 'shopping_bag',
    colorHex: '#1060E3',
    isDefault: false,
  );

  setUpAll(() => registerFallbackValue(CategoryKind.expense));

  setUp(() {
    remote = MockRemote();
    repository = CategoryRepositoryImpl(remote);
  });

  test('getAllCategories returns the categories, archived ones included',
      () async {
    const archived = CategoryModel(
      id: 'c2',
      workspaceId: 'w1',
      name: 'Antiga',
      kind: CategoryKind.expense,
      icon: 'category',
      colorHex: '#A8A8A8',
      isDefault: false,
      isArchived: true,
    );
    when(() => remote.getAllCategories('w1'))
        .thenAnswer((_) async => [model, archived]);

    final result = await repository.getAllCategories('w1');

    result.fold(
      (failure) => fail('expected categories, got $failure'),
      (categories) {
        expect(categories, hasLength(2));
        expect(categories.last.isArchived, isTrue);
      },
    );
  });

  test('createCategory returns the new category', () async {
    when(() => remote.createCategory(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          kind: any(named: 'kind'),
          icon: any(named: 'icon'),
          colorHex: any(named: 'colorHex'),
        )).thenAnswer((_) async => model);

    final result = await repository.createCategory(
      workspaceId: 'w1',
      name: 'Mercado',
      kind: CategoryKind.expense,
      icon: 'shopping_bag',
      colorHex: '#1060E3',
    );

    expect(result, const Right<Failure, CategoryEntity>(model));
  });

  test('a duplicate name becomes ConflictFailure', () async {
    when(() => remote.createCategory(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          kind: any(named: 'kind'),
          icon: any(named: 'icon'),
          colorHex: any(named: 'colorHex'),
        )).thenThrow(
      PostgrestException(message: 'duplicate key value', code: '23505'),
    );

    final result = await repository.createCategory(
      workspaceId: 'w1',
      name: 'Mercado',
      kind: CategoryKind.expense,
      icon: 'shopping_bag',
      colorHex: '#1060E3',
    );

    expect(
      result,
      const Left<Failure, CategoryEntity>(ConflictFailure('already_exists')),
    );
  });

  test('updateCategory returns the updated category', () async {
    when(() => remote.updateCategory(
          categoryId: 'c1',
          name: 'Supermercado',
          icon: 'shopping_bag',
          colorHex: '#1E7A4F',
        )).thenAnswer((_) async => model);

    final result = await repository.updateCategory(
      categoryId: 'c1',
      name: 'Supermercado',
      icon: 'shopping_bag',
      colorHex: '#1E7A4F',
    );

    expect(result.isRight(), isTrue);
  });

  test('setArchived archives and restores', () async {
    when(() => remote.setArchived('c1', archived: true))
        .thenAnswer((_) async {});
    when(() => remote.setArchived('c1', archived: false))
        .thenAnswer((_) async {});

    final archived = await repository.setArchived('c1', archived: true);
    final restored = await repository.setArchived('c1', archived: false);

    expect(archived.isRight(), isTrue);
    expect(restored.isRight(), isTrue);
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getAllCategories('w1')).thenThrow(TimeoutException('slow'));

    final result = await repository.getAllCategories('w1');

    result.fold(
      (failure) => expect(failure, const NetworkFailure('network_error')),
      (_) => fail('expected a failure'),
    );
  });
}