import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/usecases/get_cards_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The invoices of one card, plus the card itself with a fresh used limit.
class InvoicesCubit extends Cubit<InvoicesState> {
  final GetInvoicesUseCase _getInvoices;
  final GetCardsUseCase _getCards;
  CreditCardEntity? _card;

  InvoicesCubit({
    required GetInvoicesUseCase getInvoices,
    required GetCardsUseCase getCards,
  })  : _getInvoices = getInvoices,
        _getCards = getCards,
        super(const InvoicesState());

  Future<void> load(CreditCardEntity card) async {
    _card = card;
    // Keep the old data on screen while reloading, to avoid flicker.
    emit(InvoicesState(
      status: InvoicesStatus.loading,
      invoices: state.invoices,
      card: state.card ?? card,
    ));

    final invoices = await _getInvoices(card.accountId);
    final cards = await _getCards(card.workspaceId);

    Failure? failure;
    var invoiceList = const <InvoiceEntity>[];
    var cardList = const <CreditCardEntity>[];

    invoices.fold((f) {
      failure ??= f;
    }, (value) {
      invoiceList = value;
    });
    cards.fold((f) {
      failure ??= f;
    }, (value) {
      cardList = value;
    });

    final loadFailure = failure;
    if (loadFailure != null) {
      emit(InvoicesState(
        status: InvoicesStatus.failure,
        card: state.card ?? card,
        failure: loadFailure,
      ));
      return;
    }

    // A plain loop, not firstWhere(orElse: ...): the list that comes back
    // holds data-layer models, and an orElse that returns the base type
    // would throw a TypeError at runtime.
    var fresh = card;
    for (final candidate in cardList) {
      if (candidate.accountId == card.accountId) {
        fresh = candidate;
        break;
      }
    }

    emit(InvoicesState(
      status: InvoicesStatus.loaded,
      invoices: invoiceList,
      card: fresh,
    ));
  }

  Future<void> reload() async {
    final card = _card;
    if (card != null) await load(card);
  }
}