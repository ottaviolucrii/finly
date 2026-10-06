import 'package:finly/features/accounts/domain/usecases/archive_account_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/card_archive_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Archives a card. A card is an account, so this uses the account use case.
class CardArchiveCubit extends Cubit<CardArchiveState> {
  final ArchiveAccountUseCase _archiveAccount;

  CardArchiveCubit(this._archiveAccount) : super(const CardArchiveState());

  Future<void> archive(String accountId) async {
    if (state.status == CardArchiveStatus.archiving) return;

    emit(const CardArchiveState(status: CardArchiveStatus.archiving));
    final result = await _archiveAccount(accountId);
    emit(result.fold<CardArchiveState>(
      (failure) =>
          CardArchiveState(status: CardArchiveStatus.failure, failure: failure),
      (_) => const CardArchiveState(status: CardArchiveStatus.archived),
    ));
  }
}