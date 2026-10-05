import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/data/models/credit_card_model.dart';
import 'package:finly/features/cards/data/models/invoice_model.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/domain/usecases/get_cards_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetInvoices extends Mock implements GetInvoicesUseCase {}

class MockGetCards extends Mock implements GetCardsUseCase {}

// Regression test: the real data layer returns lists of models (such as
// CreditCardModel and InvoiceModel), not lists of the base entities that
// the other cubit tests use. The cubit must work with both.
void main() {
  test('load works with the model types the data layer returns', () async {
    final getInvoices = MockGetInvoices();
    final getCards = MockGetCards();

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
    const cardModel = CreditCardModel(
      accountId: 'a1',
      workspaceId: 'w1',
      name: 'Nubank',
      currency: 'BRL',
      limitCents: 500000,
      closingDay: 10,
      dueDay: 17,
      usedCents: 5000,
    );
    final invoiceModel = InvoiceModel(
      id: 'i1',
      accountId: 'a1',
      referenceMonth: DateTime(2026, 3),
      periodStart: DateTime(2026, 2, 11),
      periodEnd: DateTime(2026, 3, 10),
      dueDate: DateTime(2026, 3, 17),
      status: InvoiceStatus.open,
      totalCents: 5000,
    );

    when(() => getInvoices('a1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>(<InvoiceModel>[invoiceModel]),
    );
    when(() => getCards('w1')).thenAnswer(
      (_) async =>
          Right<Failure, List<CreditCardEntity>>(<CreditCardModel>[cardModel]),
    );

    final cubit = InvoicesCubit(getInvoices: getInvoices, getCards: getCards);
    await cubit.load(card);

    expect(cubit.state.status, InvoicesStatus.loaded);
    expect(cubit.state.invoices, hasLength(1));
    expect(cubit.state.card?.usedCents, 5000);
    await cubit.close();
  });

  test('load keeps the given card when the models do not include it', () async {
    final getInvoices = MockGetInvoices();
    final getCards = MockGetCards();

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

    when(() => getInvoices('a1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>(<InvoiceModel>[]),
    );
    when(() => getCards('w1')).thenAnswer(
      (_) async =>
          Right<Failure, List<CreditCardEntity>>(<CreditCardModel>[]),
    );

    final cubit = InvoicesCubit(getInvoices: getInvoices, getCards: getCards);
    await cubit.load(card);

    expect(cubit.state.status, InvoicesStatus.loaded);
    expect(cubit.state.card, card);
    await cubit.close();
  });
}