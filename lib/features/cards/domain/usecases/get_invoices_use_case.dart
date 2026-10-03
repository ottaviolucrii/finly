import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';

/// Params: the card's account id.
class GetInvoicesUseCase implements UseCase<List<InvoiceEntity>, String> {
  final CardRepository _repository;

  const GetInvoicesUseCase(this._repository);

  @override
  Future<Either<Failure, List<InvoiceEntity>>> call(String accountId) async {
    if (accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    return _repository.getInvoices(accountId);
  }
}