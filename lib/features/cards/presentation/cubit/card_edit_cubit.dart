import 'package:finly/features/cards/domain/usecases/update_card_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CardEditCubit extends Cubit<CardEditState> {
  final UpdateCardUseCase _updateCard;

  CardEditCubit(this._updateCard) : super(const CardEditState());

  Future<void> submit({
    required String accountId,
    required String name,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  }) async {
    if (state.status == CardEditStatus.submitting) return;

    emit(const CardEditState(status: CardEditStatus.submitting));
    final result = await _updateCard(
      UpdateCardParams(
        accountId: accountId,
        name: name,
        limitCents: limitCents,
        closingDay: closingDay,
        dueDay: dueDay,
      ),
    );
    emit(result.fold<CardEditState>(
      (failure) =>
          CardEditState(status: CardEditStatus.failure, failure: failure),
      (_) => const CardEditState(status: CardEditStatus.success),
    ));
  }
}