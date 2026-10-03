import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/cards/domain/usecases/create_card_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

void main() {
  late MockCardRepository repository;
  late CreateCardUseCase useCase;

  setUp(() {
    repository = MockCardRepository();
    useCase = CreateCardUseCase(repository);
  });

  CreateCardParams params({
    String name = 'Nubank',
    String currency = 'BRL',
    int limitCents = 500000,
    int closingDay = 10,
    int dueDay = 17,
  }) {
    return CreateCardParams(
      workspaceId: 'w1',
      name: name,
      currency: currency,
      limitCents: limitCents,
      closingDay: closingDay,
      dueDay: dueDay,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.createCard(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          currency: any(named: 'currency'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        ));
  }

  Future<void> expectRejected(CreateCardParams p, String code) async {
    final result = await useCase(p);
    expect(result, Left<Failure, String>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects an empty name', () async {
    await expectRejected(params(name: '  '), 'invalid_account_name');
  });

  test('rejects a name longer than 80 characters', () async {
    await expectRejected(params(name: 'a' * 81), 'invalid_account_name');
  });

  test('rejects an unsupported currency', () async {
    await expectRejected(params(currency: 'GBP'), 'invalid_currency');
  });

  test('rejects a zero or negative limit', () async {
    await expectRejected(params(limitCents: 0), 'invalid_limit');
    await expectRejected(params(limitCents: -1), 'invalid_limit');
  });

  test('rejects a closing day outside 1-31', () async {
    await expectRejected(params(closingDay: 0), 'invalid_day');
    await expectRejected(params(closingDay: 32), 'invalid_day');
  });

  test('rejects a due day outside 1-31', () async {
    await expectRejected(params(dueDay: 0), 'invalid_day');
    await expectRejected(params(dueDay: 32), 'invalid_day');
  });

  test('accepts day 31 (short months use the last day)', () async {
    when(() => repository.createCard(
          workspaceId: 'w1',
          name: 'Nubank',
          currency: 'BRL',
          limitCents: 500000,
          closingDay: 31,
          dueDay: 31,
        )).thenAnswer((_) async => const Right<Failure, String>('a1'));

    final result = await useCase(params(closingDay: 31, dueDay: 31));

    expect(result, const Right<Failure, String>('a1'));
  });

  test('trims the name and returns the card account id', () async {
    when(() => repository.createCard(
          workspaceId: 'w1',
          name: 'Nubank',
          currency: 'BRL',
          limitCents: 500000,
          closingDay: 10,
          dueDay: 17,
        )).thenAnswer((_) async => const Right<Failure, String>('a1'));

    final result = await useCase(params(name: '  Nubank '));

    expect(result, const Right<Failure, String>('a1'));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.createCard(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          currency: any(named: 'currency'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        )).thenAnswer(
      (_) async =>
          const Left<Failure, String>(ConflictFailure('already_exists')),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, String>(ConflictFailure('already_exists')),
    );
  });
}