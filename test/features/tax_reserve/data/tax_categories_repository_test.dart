import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/data/datasources/tax_reserve_remote_data_source.dart';
import 'package:finly/features/tax_reserve/data/repositories/tax_reserve_repository_impl.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements TaxReserveRemoteDataSource {}

void main() {
  late MockRemote remote;
  late TaxReserveRepositoryImpl repository;

  const impostos = TaxCategory(id: 'c1', name: 'Impostos', colorHex: '#1060E3', isTax: true);

  setUp(() {
    remote = MockRemote();
    repository = TaxReserveRepositoryImpl(remote);
  });

  group('getTaxCategories', () {
    test('returns what the data source read', () async {
      // The same list, because two lists with equal items are not equal in Dart.
      final categories = [impostos];
      when(() => remote.getTaxCategories('w1')).thenAnswer((_) async => categories);

      final result = await repository.getTaxCategories('w1');

      expect(result, Right<Failure, List<TaxCategory>>(categories));
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.getTaxCategories(any())).thenThrow(TimeoutException('slow'));

      final result = await repository.getTaxCategories('w1');

      expect(result, const Left<Failure, List<TaxCategory>>(NetworkFailure('network_error')));
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.getTaxCategories(any())).thenThrow(StateError('boom'));

      final result = await repository.getTaxCategories('w1');

      expect(result, const Left<Failure, List<TaxCategory>>(ServerFailure('unknown_error')));
    });

    test('a row that is not what it should be becomes a failure instead of escaping', () async {
      when(() => remote.getTaxCategories(any()))
          .thenAnswer((_) async => throw const FormatException('not a category'));

      final result = await repository.getTaxCategories('w1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('setCategoryTax', () {
    test('succeeds when the data source does', () async {
      when(() => remote.setCategoryTax('c2', isTax: true)).thenAnswer((_) async {});

      final result = await repository.setCategoryTax('c2', isTax: true);

      expect(result.isRight(), isTrue);
      verify(() => remote.setCategoryTax('c2', isTax: true)).called(1);
    });

    test('an income category refused by the database becomes a RuleFailure', () async {
      when(() => remote.setCategoryTax(any(), isTax: any(named: 'isTax'))).thenThrow(
        PostgrestException(message: 'violates check constraint "categories_check"', code: '23514'),
      );

      final result = await repository.setCategoryTax('c3', isTax: true);

      expect(
        result,
        const Left<Failure, void>(RuleFailure('violates check constraint "categories_check"')),
      );
    });

    test("someone else's category becomes PermissionFailure", () async {
      when(() => remote.setCategoryTax(any(), isTax: any(named: 'isTax')))
          .thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

      final result = await repository.setCategoryTax('c1', isTax: false);

      expect(result, const Left<Failure, void>(PermissionFailure('forbidden')));
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.setCategoryTax(any(), isTax: any(named: 'isTax')))
          .thenThrow(StateError('boom'));

      final result = await repository.setCategoryTax('c1', isTax: true);

      expect(result, const Left<Failure, void>(ServerFailure('unknown_error')));
    });
  });
}
