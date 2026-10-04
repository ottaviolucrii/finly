import 'package:finly/features/cards/domain/usecases/get_cards_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/cards_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CardsCubit extends Cubit<CardsState> {
  final GetCardsUseCase _getCards;
  String? _workspaceId;

  CardsCubit(this._getCards) : super(const CardsState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old list on screen while reloading, to avoid flicker.
    emit(CardsState(status: CardsStatus.loading, cards: state.cards));

    final result = await _getCards(workspaceId);
    emit(result.fold<CardsState>(
      (failure) => CardsState(status: CardsStatus.failure, failure: failure),
      (cards) => CardsState(status: CardsStatus.loaded, cards: cards),
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }
}