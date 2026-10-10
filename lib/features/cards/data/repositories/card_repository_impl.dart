import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/data/datasources/card_remote_data_source.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

class CardRepositoryImpl implements CardRepository {
  final CardRemoteDataSource _remote;

  const CardRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<CreditCardEntity>>> getCards(String workspaceId) {
    return _guard<List<CreditCardEntity>>(() => _remote.getCards(workspaceId));
  }

  @override
  Future<Either<Failure, String>> createCard({
    required String workspaceId,
    required String name,
    required String currency,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  }) {
    return _guard<String>(
      () => _remote.createCard(
        workspaceId: workspaceId,
        name: name,
        currency: currency,
        limitCents: limitCents,
        closingDay: closingDay,
        dueDay: dueDay,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> updateCard({
    required String accountId,
    required String name,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  }) {
    return _guard<void>(
      () => _remote.updateCard(
        accountId: accountId,
        name: name,
        limitCents: limitCents,
        closingDay: closingDay,
        dueDay: dueDay,
      ),
    );
  }

  @override
  Future<Either<Failure, List<InvoiceEntity>>> getInvoices(String accountId) {
    return _guard<List<InvoiceEntity>>(() => _remote.getInvoices(accountId));
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getInvoiceTransactions(
    String invoiceId,
  ) {
    return _guard<List<TransactionEntity>>(
      () => _remote.getInvoiceTransactions(invoiceId),
    );
  }

  @override
  Future<Either<Failure, String>> createInstallments({
    required String accountId,
    String? categoryId,
    required int totalCents,
    required int installments,
    required String description,
    required DateTime purchaseAt,
  }) {
    return _guard<String>(
      () => _remote.createInstallments(
        accountId: accountId,
        categoryId: categoryId,
        totalCents: totalCents,
        installments: installments,
        description: description,
        purchaseAt: purchaseAt,
      ),
    );
  }

  @override
  Future<Either<Failure, String>> payInvoice({
    required String invoiceId,
    required String fromAccountId,
    required DateTime paidAt,
    int? amountCents,
  }) {
    return _guard<String>(
      () => amountCents == null
          ? _remote.payInvoice(
              invoiceId: invoiceId,
              fromAccountId: fromAccountId,
              paidAt: paidAt,
            )
          : _remote.payInvoice(
              invoiceId: invoiceId,
              fromAccountId: fromAccountId,
              paidAt: paidAt,
              amountCents: amountCents,
            ),
    );
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error) are mapped to an unknown_error failure and logged.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}