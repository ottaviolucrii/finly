import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The invoices of one card.
class InvoicesCubit extends Cubit<InvoicesState> {
  final GetInvoicesUseCase _getInvoices;
  String? _accountId;

  InvoicesCubit(this._getInvoices) : super(const InvoicesState());

  Future<void> load(String accountId) async {
    _accountId = accountId;
    emit(InvoicesState(
      status: InvoicesStatus.loading,
      invoices: state.invoices,
    ));

    final result = await _getInvoices(accountId);
    emit(result.fold<InvoicesState>(
      (failure) =>
          InvoicesState(status: InvoicesStatus.failure, failure: failure),
      (invoices) =>
          InvoicesState(status: InvoicesStatus.loaded, invoices: invoices),
    ));
  }

  Future<void> reload() async {
    final id = _accountId;
    if (id != null) await load(id);
  }
}