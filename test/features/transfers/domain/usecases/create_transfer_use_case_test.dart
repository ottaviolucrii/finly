import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:finly/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:finly/features/transfers/domain/usecases/create_transfer_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransferRepository extends Mock implements TransferRepository {}

void main() {
  late MockTransferRepository repository;
  late CreateTransferUseCase useCase;

  final occurredAt = DateTime(2026, 10, 2, 12);

  setUpAll(() {
    registerFallbackValue(TransferKind.internal);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repository = MockTransferRepository();
    useCase = CreateTransferUseCase(repository);
  });

  CreateTransferParams params({
    String fromAccountId = 'a1',
    String toAccountId = 'a2',
    String fromCurrency = 'BRL',
    String toCurrency = 'BRL',
    int amountCents = 5000,
    int? toAmountCents,
    String description = 'Transferência',
    TransferKind kind = TransferKind.internal,
  }) {
    return CreateTransferParams(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      amountCents: amountCents,
      toAmountCents: toAmountCents,
      description: description,
      occurredAt: occurredAt,
      kind: kind,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.createTransfer(
          fromAccountId: any(named: 'fromAccountId'),
          toAccountId: any(named: 'toAccountId'),
          amountCents: any(named: 'amountCents'),
          toAmountCents: any(named: 'toAmountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          kind: any(named: 'kind'),
        ));
  }

  Future<void> expectRejected(CreateTransferParams p, String code) async {
    final result = await useCase(p);
    expect(result, Left<Failure, String>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects a missing account', () async {
    await expectRejected(params(toAccountId: ' '), 'invalid_account');
  });

  test('rejects the same account on both ends', () async {
    await expectRejected(params(toAccountId: 'a1'), 'same_account');
  });

  test('rejects a zero or negative amount', () async {
    await expectRejected(params(amountCents: 0), 'invalid_amount');
    await expectRejected(params(amountCents: -100), 'invalid_amount');
  });

  test('rejects an empty description', () async {
    await expectRejected(params(description: '  '), 'invalid_description');
  });

  test('between currencies the destination amount is required', () async {
    await expectRejected(
      params(toCurrency: 'USD'),
      'destination_amount_required',
    );
    await expectRejected(
      params(toCurrency: 'USD', toAmountCents: 0),
      'destination_amount_required',
    );
  });

  test('in the same currency a different destination amount is rejected',
      () async {
    await expectRejected(params(toAmountCents: 4000), 'amounts_must_match');
  });

  test('forwards a same-currency transfer and returns the transfer id',
      () async {
    when(() => repository.createTransfer(
          fromAccountId: 'a1',
          toAccountId: 'a2',
          amountCents: 5000,
          toAmountCents: null,
          description: 'Transferência',
          occurredAt: occurredAt,
          kind: TransferKind.internal,
        )).thenAnswer((_) async => const Right<Failure, String>('tr1'));

    final result = await useCase(params(description: '  Transferência '));

    expect(result, const Right<Failure, String>('tr1'));
  });

  test('forwards both amounts for a transfer between currencies', () async {
    when(() => repository.createTransfer(
          fromAccountId: 'a1',
          toAccountId: 'a2',
          amountCents: 5000,
          toAmountCents: 950,
          description: 'Transferência',
          occurredAt: occurredAt,
          kind: TransferKind.ownerWithdrawal,
        )).thenAnswer((_) async => const Right<Failure, String>('tr2'));

    final result = await useCase(params(
      toCurrency: 'USD',
      toAmountCents: 950,
      kind: TransferKind.ownerWithdrawal,
    ));

    expect(result, const Right<Failure, String>('tr2'));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.createTransfer(
          fromAccountId: any(named: 'fromAccountId'),
          toAccountId: any(named: 'toAccountId'),
          amountCents: any(named: 'amountCents'),
          toAmountCents: any(named: 'toAmountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          kind: any(named: 'kind'),
        )).thenAnswer(
      (_) async => const Left<Failure, String>(
        RuleFailure('internal transfers must stay inside one workspace'),
      ),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, String>(
        RuleFailure('internal transfers must stay inside one workspace'),
      ),
    );
  });
}