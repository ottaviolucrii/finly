import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/usecases/update_card_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUpdateCard extends Mock implements UpdateCardUseCase {}

void main() {
  late MockUpdateCard updateCard;

  const params = UpdateCardParams(
    accountId: 'a1',
    name: 'Nubank',
    limitCents: 800000,
    closingDay: 10,
    dueDay: 17,
  );

  setUp(() => updateCard = MockUpdateCard());

  Future<void> submit(CardEditCubit cubit) => cubit.submit(
        accountId: 'a1',
        name: 'Nubank',
        limitCents: 800000,
        closingDay: 10,
        dueDay: 17,
      );

  blocTest<CardEditCubit, CardEditState>(
    'emits submitting then success',
    build: () {
      when(() => updateCard(params))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return CardEditCubit(updateCard);
    },
    act: submit,
    expect: () => [
      const CardEditState(status: CardEditStatus.submitting),
      const CardEditState(status: CardEditStatus.success),
    ],
  );

  blocTest<CardEditCubit, CardEditState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => updateCard(params)).thenAnswer(
        (_) async =>
            const Left<Failure, void>(ConflictFailure('already_exists')),
      );
      return CardEditCubit(updateCard);
    },
    act: submit,
    expect: () => [
      const CardEditState(status: CardEditStatus.submitting),
      const CardEditState(
        status: CardEditStatus.failure,
        failure: ConflictFailure('already_exists'),
      ),
    ],
  );

  blocTest<CardEditCubit, CardEditState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => updateCard(params))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return CardEditCubit(updateCard);
    },
    act: submit,
    verify: (_) => verify(() => updateCard(params)).called(1),
  );
}