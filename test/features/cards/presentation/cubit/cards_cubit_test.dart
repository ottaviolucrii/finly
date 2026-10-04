import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/usecases/get_cards_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/cards_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/cards_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetCards extends Mock implements GetCardsUseCase {}

void main() {
  late MockGetCards getCards;

  const card = CreditCardEntity(
    accountId: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    currency: 'BRL',
    limitCents: 500000,
    closingDay: 10,
    dueDay: 17,
    usedCents: 125000,
  );

  setUp(() => getCards = MockGetCards());

  blocTest<CardsCubit, CardsState>(
    'load emits loading then the cards',
    build: () {
      when(() => getCards('w1')).thenAnswer(
        (_) async => const Right<Failure, List<CreditCardEntity>>([card]),
      );
      return CardsCubit(getCards);
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const CardsState(status: CardsStatus.loading),
      const CardsState(status: CardsStatus.loaded, cards: [card]),
    ],
  );

  blocTest<CardsCubit, CardsState>(
    'load emits loading then failure',
    build: () {
      when(() => getCards('w1')).thenAnswer(
        (_) async => const Left<Failure, List<CreditCardEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return CardsCubit(getCards);
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const CardsState(status: CardsStatus.loading),
      const CardsState(
        status: CardsStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<CardsCubit, CardsState>(
    'reload loads again for the same workspace',
    build: () {
      when(() => getCards('w1')).thenAnswer(
        (_) async => const Right<Failure, List<CreditCardEntity>>([card]),
      );
      return CardsCubit(getCards);
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.reload();
    },
    verify: (_) => verify(() => getCards('w1')).called(2),
  );

  blocTest<CardsCubit, CardsState>(
    'reload does nothing before the first load',
    build: () => CardsCubit(getCards),
    act: (cubit) => cubit.reload(),
    expect: () => <CardsState>[],
    verify: (_) => verifyNever(() => getCards(any())),
  );
}