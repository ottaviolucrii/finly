import 'package:finly/features/cards/domain/usecases/create_card_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CardFormCubit extends Cubit<CardFormState> {
  final CreateCardUseCase _createCard;

  CardFormCubit(this._createCard) : super(const CardFormState());

  Future<void> submit({
    required String workspaceId,
    required String name,
    required String currency,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  }) async {
    if (state.status == CardFormStatus.submitting) return;

    emit(const CardFormState(status: CardFormStatus.submitting));
    final result = await _createCard(
      CreateCardParams(
        workspaceId: workspaceId,
        name: name,
        currency: currency,
        limitCents: limitCents,
        closingDay: closingDay,
        dueDay: dueDay,
      ),
    );
    emit(result.fold<CardFormState>(
      (failure) =>
          CardFormState(status: CardFormStatus.failure, failure: failure),
      (accountId) =>
          CardFormState(status: CardFormStatus.success, accountId: accountId),
    ));
  }
}