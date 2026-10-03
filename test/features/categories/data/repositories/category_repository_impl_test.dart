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
    name: 'Alimentação',
    kind: CategoryKind.expense,
    icon: 'restaurant',
    colorHex: '#F29D38',
    isDefault: true,
  );

  setUp(() {
    remote = MockRemote();
    repository = CategoryRepositoryImpl(remote);
  });

  test('returns the categories', () async {
    when(() => remote.getCategories('w1')).thenAnswer((_) async => [model]);

    final result = await repository.getCategories('w1');

    result.fold(
      (failure) => fail('expected categories, got $failure'),
      (categories) => expect(categories, [model]),
    );
  });

  test('maps a forbidden error to PermissionFailure', () async {
    when(() => remote.getCategories('w1')).thenThrow(
      PostgrestException(message: 'forbidden', code: '42501'),
    );

    final result = await repository.getCategories('w1');

    expect(
      result,
      const Left<Failure, List<CategoryEntity>>(PermissionFailure('forbidden')),
    );
  });

  test('maps a timeout to NetworkFailure', () async {
    when(() => remote.getCategories('w1')).thenThrow(TimeoutException('slow'));

    final result = await repository.getCategories('w1');

    expect(
      result,
      const Left<Failure, List<CategoryEntity>>(
        NetworkFailure('network_error'),
      ),
    );
  });
}