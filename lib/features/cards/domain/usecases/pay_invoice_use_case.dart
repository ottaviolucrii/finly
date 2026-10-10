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

  /// How much to pay, in cents. Null pays everything that is still owed.
  final int? amountCents;

  const PayInvoiceParams({
    required this.invoiceId,
    required this.fromAccountId,
    required this.paidAt,
    this.amountCents,
  });

  @override
  List<Object?> get props => [invoiceId, fromAccountId, paidAt, amountCents];
}

/// Returns the id of the transfer that made the payment (all of the invoice, or
/// a part of it when an amount is given).
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
    final amount = params.amountCents;
    if (amount == null) {
      return _repository.payInvoice(
        invoiceId: params.invoiceId,
        fromAccountId: params.fromAccountId,
        paidAt: params.paidAt,
      );
    }
    if (amount <= 0) {
      return const Left(ValidationFailure('invalid_payment_amount'));
    }
    return _repository.payInvoice(
      invoiceId: params.invoiceId,
      fromAccountId: params.fromAccountId,
      paidAt: params.paidAt,
      amountCents: amount,
    );
  }
}