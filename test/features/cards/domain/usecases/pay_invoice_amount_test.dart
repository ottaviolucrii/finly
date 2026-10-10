import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/cards/domain/usecases/pay_invoice_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

void main() {
  late MockCardRepository repository;
  final paidAt = DateTime(2026, 3, 12);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repository = MockCardRepository());

  PayInvoiceParams params({int? amount}) => PayInvoiceParams(
        invoiceId: 'i1',
        fromAccountId: 'a2',
        paidAt: paidAt,
        amountCents: amount,
      );

  test('a part of the invoice is sent with its amount', () async {
    when(() => repository.payInvoice(
          invoiceId: 'i1',
          fromAccountId: 'a2',
          paidAt: paidAt,
          amountCents: 5000,
        )).thenAnswer((_) async => const Right<Failure, String>('tr1'));

    final result = await PayInvoiceUseCase(repository)(params(amount: 5000));

    expect(result, const Right<Failure, String>('tr1'));
  });

  test('with no amount, everything still owed is paid (no amount is sent)', () async {
    when(() => repository.payInvoice(
          invoiceId: 'i1',
          fromAccountId: 'a2',
          paidAt: paidAt,
        )).thenAnswer((_) async => const Right<Failure, String>('tr2'));

    final result = await PayInvoiceUseCase(repository)(params());

    expect(result, const Right<Failure, String>('tr2'));
    // The call is the one with no amount (a call with no amount reads as null).
    verify(() => repository.payInvoice(
          invoiceId: 'i1',
          fromAccountId: 'a2',
          paidAt: paidAt,
        )).called(1);
  });

  test('zero is rejected before asking the server', () async {
    final result = await PayInvoiceUseCase(repository)(params(amount: 0));

    expect(result, const Left<Failure, String>(ValidationFailure('invalid_payment_amount')));
    verifyNever(() => repository.payInvoice(
          invoiceId: any(named: 'invoiceId'),
          fromAccountId: any(named: 'fromAccountId'),
          paidAt: any(named: 'paidAt'),
          amountCents: any(named: 'amountCents'),
        ));
  });

  test('a negative amount is rejected', () async {
    final result = await PayInvoiceUseCase(repository)(params(amount: -1));

    expect(result, const Left<Failure, String>(ValidationFailure('invalid_payment_amount')));
  });

  test('a missing invoice is still rejected first', () async {
    final result = await PayInvoiceUseCase(repository)(
      PayInvoiceParams(invoiceId: ' ', fromAccountId: 'a2', paidAt: paidAt, amountCents: 100),
    );

    expect(result, const Left<Failure, String>(ValidationFailure('invalid_invoice')));
  });

  test('a refusal of the server for the amount is passed through', () async {
    when(() => repository.payInvoice(
          invoiceId: any(named: 'invoiceId'),
          fromAccountId: any(named: 'fromAccountId'),
          paidAt: any(named: 'paidAt'),
          amountCents: any(named: 'amountCents'),
        )).thenAnswer(
      (_) async => const Left<Failure, String>(RuleFailure('payment amount is above what is owed')),
    );

    final result = await PayInvoiceUseCase(repository)(params(amount: 999999));

    expect(result, const Left<Failure, String>(RuleFailure('payment amount is above what is owed')));
  });

  group('PayInvoiceParams', () {
    test('the amount takes part in equality', () {
      expect(params(amount: 100), params(amount: 100));
      expect(params(amount: 100), isNot(params(amount: 200)));
      expect(params(amount: 100), isNot(params()));
    });

    test('no amount is the default', () {
      expect(params().amountCents, isNull);
    });
  });
}
