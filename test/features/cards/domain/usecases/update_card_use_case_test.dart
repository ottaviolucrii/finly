import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/cards/domain/usecases/update_card_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

void main() {
  late MockCardRepository repository;
  late UpdateCardUseCase useCase;

  setUp(() {
    repository = MockCardRepository();
    useCase = UpdateCardUseCase(repository);
  });

  UpdateCardParams params({
    String accountId = 'a1',
    String name = 'Nubank',
    int limitCents = 800000,
    int closingDay = 10,
    int dueDay = 17,
  }) {
    return UpdateCardParams(
      accountId: accountId,
      name: name,
      limitCents: limitCents,
      closingDay: closingDay,
      dueDay: dueDay,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.updateCard(
          accountId: any(named: 'accountId'),
          name: any(named: 'name'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        ));
  }

  Future<void> expectRejected(UpdateCardParams p, String code) async {
    final result = await useCase(p);
    expect(result, Left<Failure, void>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects a missing account', () async {
    await expectRejected(params(accountId: ' '), 'invalid_account');
  });

  test('rejects an empty or too long name', () async {
    await expectRejected(params(name: '  '), 'invalid_account_name');
    await expectRejected(params(name: 'a' * 81), 'invalid_account_name');
  });

  test('rejects a zero or negative limit', () async {
    await expectRejected(params(limitCents: 0), 'invalid_limit');
    await expectRejected(params(limitCents: -1), 'invalid_limit');
  });

  test('rejects days outside 1-31', () async {
    await expectRejected(params(closingDay: 0), 'invalid_day');
    await expectRejected(params(closingDay: 32), 'invalid_day');
    await expectRejected(params(dueDay: 0), 'invalid_day');
    await expectRejected(params(dueDay: 32), 'invalid_day');
  });

  test('trims the name and forwards the change to the repository', () async {
    when(() => repository.updateCard(
          accountId: 'a1',
          name: 'Nubank Roxinho',
          limitCents: 800000,
          closingDay: 10,
          dueDay: 17,
        )).thenAnswer((_) async => const Right<Failure, void>(null));

    final result = await useCase(params(name: '  Nubank Roxinho '));

    expect(result.isRight(), isTrue);
    verify(() => repository.updateCard(
          accountId: 'a1',
          name: 'Nubank Roxinho',
          limitCents: 800000,
          closingDay: 10,
          dueDay: 17,
        )).called(1);
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.updateCard(
          accountId: any(named: 'accountId'),
          name: any(named: 'name'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        )).thenAnswer(
      (_) async =>
          const Left<Failure, void>(ConflictFailure('already_exists')),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, void>(ConflictFailure('already_exists')),
    );
  });
}