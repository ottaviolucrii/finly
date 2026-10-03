import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:finly/features/transfers/domain/repositories/transfer_repository.dart';

class CreateTransferParams extends Equatable {
  final String fromAccountId;
  final String toAccountId;

  /// Needed to know whether a destination amount is required.
  final String fromCurrency;
  final String toCurrency;

  /// What leaves the origin account, in cents.
  final int amountCents;

  /// What arrives, in cents. Only for transfers between currencies.
  final int? toAmountCents;
  final String description;
  final DateTime occurredAt;
  final TransferKind kind;

  const CreateTransferParams({
    required this.fromAccountId,
    required this.toAccountId,
    required this.fromCurrency,
    required this.toCurrency,
    required this.amountCents,
    this.toAmountCents,
    required this.description,
    required this.occurredAt,
    required this.kind,
  });

  @override
  List<Object?> get props => [
        fromAccountId,
        toAccountId,
        fromCurrency,
        toCurrency,
        amountCents,
        toAmountCents,
        description,
        occurredAt,
        kind,
      ];
}

/// Returns the id of the new transfer.
class CreateTransferUseCase implements UseCase<String, CreateTransferParams> {
  final TransferRepository _repository;

  const CreateTransferUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(CreateTransferParams params) async {
    if (params.fromAccountId.trim().isEmpty ||
        params.toAccountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    if (params.fromAccountId == params.toAccountId) {
      return const Left(ValidationFailure('same_account'));
    }
    if (params.amountCents <= 0) {
      return const Left(ValidationFailure('invalid_amount'));
    }
    final description = params.description.trim();
    if (description.isEmpty || description.length > 200) {
      return const Left(ValidationFailure('invalid_description'));
    }

    final crossCurrency = params.fromCurrency != params.toCurrency;
    final toAmount = params.toAmountCents;
    if (crossCurrency) {
      if (toAmount == null || toAmount <= 0) {
        return const Left(ValidationFailure('destination_amount_required'));
      }
    } else if (toAmount != null && toAmount != params.amountCents) {
      return const Left(ValidationFailure('amounts_must_match'));
    }

    return _repository.createTransfer(
      fromAccountId: params.fromAccountId,
      toAccountId: params.toAccountId,
      amountCents: params.amountCents,
      toAmountCents: crossCurrency ? toAmount : null,
      description: description,
      occurredAt: params.occurredAt,
      kind: params.kind,
    );
  }
}