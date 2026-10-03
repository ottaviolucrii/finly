import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/cards/domain/usecases/create_installments_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

void main() {
  late MockCardRepository repository;
  late CreateInstallmentsUseCase useCase;

  final purchaseAt = DateTime(2026, 3, 5, 12);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    repository = MockCardRepository();
    useCase = CreateInstallmentsUseCase(repository);
  });

  CreateInstallmentsParams params({
    String accountId = 'a1',
    String? categoryId = 'c1',
    int totalCents = 100001,
    int installments = 3,
    String description = 'TV',
  }) {
    return CreateInstallmentsParams(
      accountId: accountId,
      categoryId: categoryId,
      totalCents: totalCents,
      installments: installments,
      description: description,
      purchaseAt: purchaseAt,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.createInstallments(
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          totalCents: any(named: 'totalCents'),
          installments: any(named: 'installments'),
          description: any(named: 'description'),
          purchaseAt: any(named: 'purchaseAt'),
        ));
  }

  Future<void> expectRejected(CreateInstallmentsParams p, String code) async {
    final result = await useCase(p);
    expect(result, Left<Failure, String>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects a missing account', () async {
    await expectRejected(params(accountId: ' '), 'invalid_account');
  });

  test('rejects fewer than 2 or more than 48 installments', () async {
    await expectRejected(params(installments: 1), 'invalid_installments');
    await expectRejected(params(installments: 49), 'invalid_installments');
  });

  test('rejects a total smaller than one cent per installment', () async {
    await expectRejected(
      params(totalCents: 5, installments: 6),
      'invalid_amount',
    );
  });

  test('rejects an empty description', () async {
    await expectRejected(params(description: ' '), 'invalid_description');
  });

  test('accepts the limits: 2 and 48 installments', () async {
    when(() => repository.createInstallments(
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          totalCents: any(named: 'totalCents'),
          installments: any(named: 'installments'),
          description: any(named: 'description'),
          purchaseAt: any(named: 'purchaseAt'),
        )).thenAnswer((_) async => const Right<Failure, String>('g1'));

    expect((await useCase(params(installments: 2))).isRight(), isTrue);
    expect((await useCase(params(installments: 48))).isRight(), isTrue);
  });

  test('trims the description and returns the group id', () async {
    when(() => repository.createInstallments(
          accountId: 'a1',
          categoryId: 'c1',
          totalCents: 100001,
          installments: 3,
          description: 'TV',
          purchaseAt: purchaseAt,
        )).thenAnswer((_) async => const Right<Failure, String>('g1'));

    final result = await useCase(params(description: '  TV '));

    expect(result, const Right<Failure, String>('g1'));
  });

  test('works without a category', () async {
    when(() => repository.createInstallments(
          accountId: 'a1',
          categoryId: null,
          totalCents: 100001,
          installments: 3,
          description: 'TV',
          purchaseAt: purchaseAt,
        )).thenAnswer((_) async => const Right<Failure, String>('g2'));

    final result = await useCase(params(categoryId: null));

    expect(result, const Right<Failure, String>('g2'));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.createInstallments(
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          totalCents: any(named: 'totalCents'),
          installments: any(named: 'installments'),
          description: any(named: 'description'),
          purchaseAt: any(named: 'purchaseAt'),
        )).thenAnswer(
      (_) async => const Left<Failure, String>(
        PermissionFailure('forbidden'),
      ),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, String>(PermissionFailure('forbidden')),
    );
  });
}