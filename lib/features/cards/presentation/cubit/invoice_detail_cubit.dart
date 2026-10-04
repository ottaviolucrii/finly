import 'package:finly/features/cards/domain/usecases/get_invoice_transactions_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The contents of one invoice.
class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  final GetInvoiceTransactionsUseCase _getTransactions;
  String? _invoiceId;

  InvoiceDetailCubit(this._getTransactions) : super(const InvoiceDetailState());

  Future<void> load(String invoiceId) async {
    _invoiceId = invoiceId;
    emit(InvoiceDetailState(
      status: InvoiceDetailStatus.loading,
      transactions: state.transactions,
    ));

    final result = await _getTransactions(invoiceId);
    emit(result.fold<InvoiceDetailState>(
      (failure) => InvoiceDetailState(
        status: InvoiceDetailStatus.failure,
        failure: failure,
      ),
      (transactions) => InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        transactions: transactions,
      ),
    ));
  }

  Future<void> reload() async {
    final id = _invoiceId;
    if (id != null) await load(id);
  }
}