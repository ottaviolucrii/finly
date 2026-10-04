import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/usecases/create_card_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateCard extends Mock implements CreateCardUseCase {}

void main() {
  late MockCreateCard createCard;

  const params = CreateCardParams(
    workspaceId: 'w1',
    name: 'Nubank',
    currency: 'BRL',
    limitCents: 500000,
    closingDay: 10,
    dueDay: 17,
  );

  setUp(() => createCard = MockCreateCard());

  Future<void> submit(CardFormCubit cubit) => cubit.submit(
        workspaceId: 'w1',
        name: 'Nubank',
        currency: 'BRL',
        limitCents: 500000,
        closingDay: 10,
        dueDay: 17,
      );

  blocTest<CardFormCubit, CardFormState>(
    'emits submitting then success with the card account id',
    build: () {
      when(() => createCard(params))
          .thenAnswer((_) async => const Right<Failure, String>('a1'));
      return CardFormCubit(createCard);
    },
    act: submit,
    expect: () => [
      const CardFormState(status: CardFormStatus.submitting),
      const CardFormState(status: CardFormStatus.success, accountId: 'a1'),
    ],
  );

  blocTest<CardFormCubit, CardFormState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => createCard(params)).thenAnswer(
        (_) async =>
            const Left<Failure, String>(ConflictFailure('already_exists')),
      );
      return CardFormCubit(createCard);
    },
    act: submit,
    expect: () => [
      const CardFormState(status: CardFormStatus.submitting),
      const CardFormState(
        status: CardFormStatus.failure,
        failure: ConflictFailure('already_exists'),
      ),
    ],
  );

  blocTest<CardFormCubit, CardFormState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => createCard(params))
          .thenAnswer((_) async => const Right<Failure, String>('a1'));
      return CardFormCubit(createCard);
    },
    act: submit,
    verify: (_) => verify(() => createCard(params)).called(1),
  );
}