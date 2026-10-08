import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:finly/features/tax_reserve/domain/usecases/get_tax_categories_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/set_category_tax_use_case.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGet extends Mock implements GetTaxCategoriesUseCase {}

class MockSet extends Mock implements SetCategoryTaxUseCase {}

void main() {
  late MockGet getCategories;
  late MockSet setCategoryTax;

  const impostos = TaxCategory(id: 'c1', name: 'Impostos', colorHex: '#1060E3', isTax: true);
  const aluguel = TaxCategory(id: 'c2', name: 'Aluguel', colorHex: '#F29D38', isTax: false);
  const taxas = TaxCategory(id: 'c3', name: 'Taxas', colorHex: '#8E24AA', isTax: false);

  setUpAll(() => registerFallbackValue(const SetCategoryTaxParams(categoryId: 'c1', isTax: true)));

  setUp(() {
    getCategories = MockGet();
    setCategoryTax = MockSet();
  });

  TaxCategoriesCubit build() => TaxCategoriesCubit(
        getCategories: getCategories,
        setCategoryTax: setCategoryTax,
      );

  void stubLoad(List<TaxCategory> list) {
    when(() => getCategories('w1')).thenAnswer((_) async => Right<Failure, List<TaxCategory>>(list));
  }

  test('starts loading, with nothing on screen', () {
    final cubit = build();

    expect(cubit.state.status, TaxCategoriesStatus.loading);
    expect(cubit.state.categories, isEmpty);
    expect(cubit.state.changes, 0);
    cubit.close();
  });

  test('load shows the categories', () async {
    stubLoad([impostos, aluguel]);
    final cubit = build();

    await cubit.load('w1');

    expect(cubit.state.status, TaxCategoriesStatus.loaded);
    expect(cubit.state.categories, [impostos, aluguel]);
    await cubit.close();
  });

  test('markedNames lists the categories that count as a tax', () async {
    stubLoad([impostos, aluguel, taxas.withTax(true)]);
    final cubit = build();

    await cubit.load('w1');

    expect(cubit.state.markedNames, ['Impostos', 'Taxas']);
    await cubit.close();
  });

  test('a failure with nothing to show is reported', () async {
    when(() => getCategories(any())).thenAnswer(
      (_) async => const Left<Failure, List<TaxCategory>>(NetworkFailure('network_error')),
    );
    final cubit = build();

    await cubit.load('w1');

    expect(cubit.state.status, TaxCategoriesStatus.failure);
    expect(cubit.state.failure, const NetworkFailure('network_error'));
    await cubit.close();
  });

  test('reload before the first load does nothing', () async {
    final cubit = build();

    await cubit.reload();

    verifyNever(() => getCategories(any()));
    await cubit.close();
  });

  group('setTax', () {
    test('moves the switch at once and counts the saved change', () async {
      stubLoad([impostos, aluguel]);
      final gate = Completer<Either<Failure, void>>();
      when(() => setCategoryTax(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load('w1');

      final saving = cubit.setTax('c2', isTax: true);

      expect(cubit.state.savingId, 'c2');
      expect(cubit.state.categories.last.isTax, isTrue);
      expect(cubit.state.changes, 0);

      gate.complete(const Right<Failure, void>(null));
      await saving;

      expect(cubit.state.savingId, isNull);
      expect(cubit.state.categories.last.isTax, isTrue);
      expect(cubit.state.changes, 1);
      verify(() => setCategoryTax(const SetCategoryTaxParams(categoryId: 'c2', isTax: true))).called(1);
      await cubit.close();
    });

    test('takes the mark off', () async {
      stubLoad([impostos, aluguel]);
      when(() => setCategoryTax(any())).thenAnswer((_) async => const Right<Failure, void>(null));
      final cubit = build();
      await cubit.load('w1');

      await cubit.setTax('c1', isTax: false);

      expect(cubit.state.categories.first.isTax, isFalse);
      expect(cubit.state.markedNames, isEmpty);
      await cubit.close();
    });

    test('a refused change puts the switch back and says why', () async {
      stubLoad([impostos, aluguel]);
      when(() => setCategoryTax(any())).thenAnswer(
        (_) async => const Left<Failure, void>(RuleFailure('violates check constraint')),
      );
      final cubit = build();
      await cubit.load('w1');

      await cubit.setTax('c2', isTax: true);

      expect(cubit.state.categories, [impostos, aluguel]);
      expect(cubit.state.saveFailure, const RuleFailure('violates check constraint'));
      expect(cubit.state.savingId, isNull);
      expect(cubit.state.changes, 0);
      await cubit.close();
    });

    test('a second change while one is being saved is ignored', () async {
      stubLoad([impostos, aluguel, taxas]);
      final gate = Completer<Either<Failure, void>>();
      when(() => setCategoryTax(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load('w1');

      final first = cubit.setTax('c2', isTax: true);
      await cubit.setTax('c3', isTax: true);
      gate.complete(const Right<Failure, void>(null));
      await first;

      verify(() => setCategoryTax(any())).called(1);
      expect(cubit.state.categories.last.isTax, isFalse);
      await cubit.close();
    });

    test('a change to the value it already has does nothing', () async {
      stubLoad([impostos]);
      final cubit = build();
      await cubit.load('w1');

      await cubit.setTax('c1', isTax: true);

      verifyNever(() => setCategoryTax(any()));
      await cubit.close();
    });

    test('a category that is not there does nothing', () async {
      stubLoad([impostos]);
      final cubit = build();
      await cubit.load('w1');

      await cubit.setTax('nope', isTax: true);

      verifyNever(() => setCategoryTax(any()));
      await cubit.close();
    });

    test('each saved change counts, so the screen reads the numbers again each time', () async {
      stubLoad([impostos, aluguel]);
      when(() => setCategoryTax(any())).thenAnswer((_) async => const Right<Failure, void>(null));
      final cubit = build();
      await cubit.load('w1');

      await cubit.setTax('c2', isTax: true);
      await cubit.setTax('c1', isTax: false);

      expect(cubit.state.changes, 2);
      await cubit.close();
    });

    test('a reload keeps the count of changes', () async {
      stubLoad([impostos, aluguel]);
      when(() => setCategoryTax(any())).thenAnswer((_) async => const Right<Failure, void>(null));
      final cubit = build();
      await cubit.load('w1');
      await cubit.setTax('c2', isTax: true);

      await cubit.reload();

      expect(cubit.state.changes, 1);
      await cubit.close();
    });
  });
}
