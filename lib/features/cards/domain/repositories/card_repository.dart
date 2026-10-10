import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

abstract class CardRepository {
  /// Active cards of a workspace, with their used limit.
  Future<Either<Failure, List<CreditCardEntity>>> getCards(String workspaceId);

  /// Creates the card account and its settings together. Returns the card's
  /// account id.
  Future<Either<Failure, String>> createCard({
    required String workspaceId,
    required String name,
    required String currency,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  });

  /// Changes the name, the limit and the closing and due days of a card. The
  /// currency never changes. The days apply to the next invoices; invoices
  /// that already exist keep their dates.
  Future<Either<Failure, void>> updateCard({
    required String accountId,
    required String name,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  });

  /// Invoices of a card, newest first.
  Future<Either<Failure, List<InvoiceEntity>>> getInvoices(String accountId);

  /// The purchases (and refunds) inside one invoice, newest first.
  Future<Either<Failure, List<TransactionEntity>>> getInvoiceTransactions(
    String invoiceId,
  );

  /// One purchase split into [installments] parts on consecutive invoices.
  /// Returns the installment group id.
  Future<Either<Failure, String>> createInstallments({
    required String accountId,
    String? categoryId,
    required int totalCents,
    required int installments,
    required String description,
    required DateTime purchaseAt,
  });

  /// Pays [amountCents] of the invoice from another account, or everything
  /// still owed when it is null. The invoice is marked paid only when nothing
  /// is owed any more. Returns the id of the transfer that made the payment.
  Future<Either<Failure, String>> payInvoice({
    required String invoiceId,
    required String fromAccountId,
    required DateTime paidAt,
    int? amountCents,
  });
}