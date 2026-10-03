import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/cards/domain/usecases/get_cards_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoice_transactions_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/domain/usecases/pay_invoice_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

void main() {
  late MockCardRepository repository;

  final paidAt = DateTime(2026, 3, 12, 12);

  const card = CreditCardEntity(
    accountId: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    currency: 'BRL',
    limitCents: 500000,
    closingDay: 10,
    dueDay: 17,
    usedCents: 0,
  );
  final invoice = InvoiceEntity(
    id: 'i1',
    accountId: 'a1',
    referenceMonth: DateTime(2026, 3),
    periodStart: DateTime(2026, 2, 11),
    periodEnd: DateTime(2026, 3, 10),
    dueDate: DateTime(2026, 3, 17),
    status: InvoiceStatus.closed,
    totalCents: 10000,
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repository = MockCardRepository());

  group('GetCardsUseCase', () {
    test('rejects an empty workspace id', () async {
      final result = await GetCardsUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, List<CreditCardEntity>>(
          ValidationFailure('invalid_workspace'),
        ),
      );
      verifyNever(() => repository.getCards(any()));
    });

    test('returns the cards of the workspace', () async {
      when(() => repository.getCards('w1')).thenAnswer(
        (_) async => const Right<Failure, List<CreditCardEntity>>([card]),
      );

      final result = await GetCardsUseCase(repository)('w1');

      result.fold(
        (failure) => fail('expected cards, got $failure'),
        (cards) => expect(cards, [card]),
      );
    });
  });

  group('GetInvoicesUseCase', () {
    test('rejects an empty account id', () async {
      final result = await GetInvoicesUseCase(repository)('');

      expect(
        result,
        const Left<Failure, List<InvoiceEntity>>(
          ValidationFailure('invalid_account'),
        ),
      );
      verifyNever(() => repository.getInvoices(any()));
    });

    test('returns the invoices of the card', () async {
      when(() => repository.getInvoices('a1')).thenAnswer(
        (_) async => Right<Failure, List<InvoiceEntity>>([invoice]),
      );

      final result = await GetInvoicesUseCase(repository)('a1');

      result.fold(
        (failure) => fail('expected invoices, got $failure'),
        (invoices) => expect(invoices, [invoice]),
      );
    });
  });

  group('GetInvoiceTransactionsUseCase', () {
    test('rejects an empty invoice id', () async {
      final result = await GetInvoiceTransactionsUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, List<TransactionEntity>>(
          ValidationFailure('invalid_invoice'),
        ),
      );
      verifyNever(() => repository.getInvoiceTransactions(any()));
    });

    test('returns the transactions of the invoice', () async {
      when(() => repository.getInvoiceTransactions('i1')).thenAnswer(
        (_) async => const Right<Failure, List<TransactionEntity>>([]),
      );

      final result = await GetInvoiceTransactionsUseCase(repository)('i1');

      expect(result.isRight(), isTrue);
      verify(() => repository.getInvoiceTransactions('i1')).called(1);
    });
  });

  group('PayInvoiceUseCase', () {
    void verifyRepositoryNotCalled() {
      verifyNever(() => repository.payInvoice(
            invoiceId: any(named: 'invoiceId'),
            fromAccountId: any(named: 'fromAccountId'),
            paidAt: any(named: 'paidAt'),
          ));
    }

    test('rejects a missing invoice', () async {
      final result = await PayInvoiceUseCase(repository)(
        PayInvoiceParams(invoiceId: ' ', fromAccountId: 'a2', paidAt: paidAt),
      );

      expect(
        result,
        const Left<Failure, String>(ValidationFailure('invalid_invoice')),
      );
      verifyRepositoryNotCalled();
    });

    test('rejects a missing source account', () async {
      final result = await PayInvoiceUseCase(repository)(
        PayInvoiceParams(invoiceId: 'i1', fromAccountId: '', paidAt: paidAt),
      );

      expect(
        result,
        const Left<Failure, String>(ValidationFailure('invalid_account')),
      );
      verifyRepositoryNotCalled();
    });

    test('pays the invoice and returns the transfer id', () async {
      when(() => repository.payInvoice(
            invoiceId: 'i1',
            fromAccountId: 'a2',
            paidAt: paidAt,
          )).thenAnswer((_) async => const Right<Failure, String>('tr1'));

      final result = await PayInvoiceUseCase(repository)(
        PayInvoiceParams(invoiceId: 'i1', fromAccountId: 'a2', paidAt: paidAt),
      );

      expect(result, const Right<Failure, String>('tr1'));
    });

    test('passes a repository failure through unchanged', () async {
      when(() => repository.payInvoice(
            invoiceId: any(named: 'invoiceId'),
            fromAccountId: any(named: 'fromAccountId'),
            paidAt: any(named: 'paidAt'),
          )).thenAnswer(
        (_) async => const Left<Failure, String>(
          RuleFailure('invoice already paid'),
        ),
      );

      final result = await PayInvoiceUseCase(repository)(
        PayInvoiceParams(invoiceId: 'i1', fromAccountId: 'a2', paidAt: paidAt),
      );

      expect(
        result,
        const Left<Failure, String>(RuleFailure('invoice already paid')),
      );
    });
  });
}