import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
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

void main() {
  late MockGetInvoices getInvoices;
  late MockGetCards getCards;

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
  const usedCard = CreditCardEntity(
    accountId: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    currency: 'BRL',
    limitCents: 500000,
    closingDay: 10,
    dueDay: 17,
    usedCents: 100001,
  );
  final invoice = InvoiceEntity(
    id: 'i1',
    accountId: 'a1',
    referenceMonth: DateTime(2026, 3),
    periodStart: DateTime(2026, 2, 11),
    periodEnd: DateTime(2026, 3, 10),
    dueDate: DateTime(2026, 3, 17),
    status: InvoiceStatus.open,
    totalCents: 100001,
  );

  setUp(() {
    getInvoices = MockGetInvoices();
    getCards = MockGetCards();
  });

  InvoicesCubit buildCubit() =>
      InvoicesCubit(getInvoices: getInvoices, getCards: getCards);

  void stubInvoices() {
    when(() => getInvoices('a1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>([invoice]),
    );
  }

  blocTest<InvoicesCubit, InvoicesState>(
    'load emits loading, then the invoices and the card with a fresh limit',
    build: () {
      stubInvoices();
      when(() => getCards('w1')).thenAnswer(
        (_) async => const Right<Failure, List<CreditCardEntity>>([usedCard]),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load(card),
    expect: () => [
      const InvoicesState(status: InvoicesStatus.loading, card: card),
      InvoicesState(
        status: InvoicesStatus.loaded,
        invoices: [invoice],
        card: usedCard,
      ),
    ],
  );

  blocTest<InvoicesCubit, InvoicesState>(
    'keeps the card it was given when the cards list does not include it',
    build: () {
      stubInvoices();
      when(() => getCards('w1')).thenAnswer(
        (_) async => const Right<Failure, List<CreditCardEntity>>([]),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load(card),
    expect: () => [
      const InvoicesState(status: InvoicesStatus.loading, card: card),
      InvoicesState(
        status: InvoicesStatus.loaded,
        invoices: [invoice],
        card: card,
      ),
    ],
  );

  blocTest<InvoicesCubit, InvoicesState>(
    'load fails as a whole when any part fails',
    build: () {
      when(() => getInvoices('a1')).thenAnswer(
        (_) async => const Left<Failure, List<InvoiceEntity>>(
          PermissionFailure('forbidden'),
        ),
      );
      when(() => getCards('w1')).thenAnswer(
        (_) async => const Right<Failure, List<CreditCardEntity>>([card]),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load(card),
    expect: () => [
      const InvoicesState(status: InvoicesStatus.loading, card: card),
      const InvoicesState(
        status: InvoicesStatus.failure,
        card: card,
        failure: PermissionFailure('forbidden'),
      ),
    ],
  );

  blocTest<InvoicesCubit, InvoicesState>(
    'reload loads the same card again',
    build: () {
      stubInvoices();
      when(() => getCards('w1')).thenAnswer(
        (_) async => const Right<Failure, List<CreditCardEntity>>([card]),
      );
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load(card);
      await cubit.reload();
    },
    verify: (_) => verify(() => getInvoices('a1')).called(2),
  );

  blocTest<InvoicesCubit, InvoicesState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <InvoicesState>[],
    verify: (_) => verifyNever(() => getInvoices(any())),
  );
}