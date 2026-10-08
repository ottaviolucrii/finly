import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/data/datasources/tax_reserve_remote_data_source.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:finly/features/tax_reserve/domain/repositories/tax_reserve_repository.dart';
import 'package:finly/features/tax_reserve/domain/usecases/get_tax_categories_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/set_category_tax_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements TaxReserveRepository {}

void main() {
  late MockRepository repository;

  const impostos = TaxCategory(id: 'c1', name: 'Impostos', colorHex: '#1060E3', isTax: true);
  const aluguel = TaxCategory(id: 'c2', name: 'Aluguel', colorHex: '#F29D38', isTax: false);

  setUp(() => repository = MockRepository());

  group('TaxCategory', () {
    test('withTax changes only the mark', () {
      final changed = aluguel.withTax(true);

      expect(changed.isTax, isTrue);
      expect(changed.id, 'c2');
      expect(changed.name, 'Aluguel');
      expect(changed.colorHex, '#F29D38');
      expect(aluguel.isTax, isFalse);
    });

    test('is equal when everything is equal', () {
      expect(
        const TaxCategory(id: 'c1', name: 'Impostos', colorHex: '#1060E3', isTax: true),
        impostos,
      );
    });
  });

  group('taxCategoryFromRow', () {
    final row = <String, dynamic>{
      'id': 'c1',
      'name': 'Impostos',
      'color': '#1060E3',
      'is_tax': true,
    };

    test('reads a row of the table', () {
      expect(taxCategoryFromRow(row), impostos);
    });

    test('reads a category that is not a tax', () {
      expect(taxCategoryFromRow({...row, 'is_tax': false}).isTax, isFalse);
    });

    test('a column that is not what it should be is an error', () {
      expect(() => taxCategoryFromRow({...row, 'name': null}), throwsA(isA<TypeError>()));
      expect(() => taxCategoryFromRow({...row, 'is_tax': null}), throwsA(isA<TypeError>()));
    });
  });

  group('GetTaxCategoriesUseCase', () {
    test('rejects an empty workspace id', () async {
      final result = await GetTaxCategoriesUseCase(repository)(' ');

      expect(result, const Left<Failure, List<TaxCategory>>(ValidationFailure('invalid_workspace')));
      verifyNever(() => repository.getTaxCategories(any()));
    });

    test('returns the categories of the repository', () async {
      when(() => repository.getTaxCategories('w1'))
          .thenAnswer((_) async => const Right<Failure, List<TaxCategory>>([impostos, aluguel]));

      final result = await GetTaxCategoriesUseCase(repository)('w1');

      expect(result, const Right<Failure, List<TaxCategory>>([impostos, aluguel]));
    });

    test('passes a failure through unchanged', () async {
      when(() => repository.getTaxCategories(any())).thenAnswer(
        (_) async => const Left<Failure, List<TaxCategory>>(NetworkFailure('network_error')),
      );

      final result = await GetTaxCategoriesUseCase(repository)('w1');

      expect(result, const Left<Failure, List<TaxCategory>>(NetworkFailure('network_error')));
    });
  });

  group('SetCategoryTaxUseCase', () {
    test('rejects an empty category id', () async {
      final result = await SetCategoryTaxUseCase(repository)(
        const SetCategoryTaxParams(categoryId: ' ', isTax: true),
      );

      expect(result, const Left<Failure, void>(ValidationFailure('invalid_category')));
      verifyNever(() => repository.setCategoryTax(any(), isTax: any(named: 'isTax')));
    });

    test('marks a category', () async {
      when(() => repository.setCategoryTax('c2', isTax: true))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await SetCategoryTaxUseCase(repository)(
        const SetCategoryTaxParams(categoryId: 'c2', isTax: true),
      );

      expect(result.isRight(), isTrue);
      verify(() => repository.setCategoryTax('c2', isTax: true)).called(1);
    });

    test('takes the mark off', () async {
      when(() => repository.setCategoryTax('c1', isTax: false))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      await SetCategoryTaxUseCase(repository)(
        const SetCategoryTaxParams(categoryId: 'c1', isTax: false),
      );

      verify(() => repository.setCategoryTax('c1', isTax: false)).called(1);
    });

    test('passes the refusal of the database through unchanged', () async {
      when(() => repository.setCategoryTax(any(), isTax: any(named: 'isTax'))).thenAnswer(
        (_) async => const Left<Failure, void>(RuleFailure('violates check constraint')),
      );

      final result = await SetCategoryTaxUseCase(repository)(
        const SetCategoryTaxParams(categoryId: 'c9', isTax: true),
      );

      expect(result, const Left<Failure, void>(RuleFailure('violates check constraint')));
    });

    test('params with the same values are equal', () {
      expect(
        const SetCategoryTaxParams(categoryId: 'c1', isTax: true),
        const SetCategoryTaxParams(categoryId: 'c1', isTax: true),
      );
    });
  });
}
