import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';

class PayInvoiceParams extends Equatable {
  final String invoiceId;

  /// The account the money comes from. Must use the card's currency.
  final String fromAccountId;
  final DateTime paidAt;

  const PayInvoiceParams({
    required this.invoiceId,
    required this.fromAccountId,
    required this.paidAt,
  });

  @override
  List<Object?> get props => [invoiceId, fromAccountId, paidAt];
}

/// Returns the id of the transfer that paid the invoice.
class PayInvoiceUseCase implements UseCase<String, PayInvoiceParams> {
  final CardRepository _repository;

  const PayInvoiceUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(PayInvoiceParams params) async {
    if (params.invoiceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_invoice'));
    }
    if (params.fromAccountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    return _repository.payInvoice(
      invoiceId: params.invoiceId,
      fromAccountId: params.fromAccountId,
      paidAt: params.paidAt,
    );
  }
}