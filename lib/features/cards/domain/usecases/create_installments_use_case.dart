import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';

class CreateInstallmentsParams extends Equatable {
  final String accountId;
  final String? categoryId;

  /// The whole purchase, in cents.
  final int totalCents;
  final int installments;
  final String description;
  final DateTime purchaseAt;

  const CreateInstallmentsParams({
    required this.accountId,
    this.categoryId,
    required this.totalCents,
    required this.installments,
    required this.description,
    required this.purchaseAt,
  });

  @override
  List<Object?> get props => [
        accountId,
        categoryId,
        totalCents,
        installments,
        description,
        purchaseAt,
      ];
}

/// Returns the installment group id.
class CreateInstallmentsUseCase
    implements UseCase<String, CreateInstallmentsParams> {
  final CardRepository _repository;

  const CreateInstallmentsUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(CreateInstallmentsParams params) async {
    if (params.accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    // SRS BR-14: 2 to 48 parts.
    if (params.installments < 2 || params.installments > 48) {
      return const Left(ValidationFailure('invalid_installments'));
    }
    // At least one cent per part.
    if (params.totalCents < params.installments) {
      return const Left(ValidationFailure('invalid_amount'));
    }
    final description = params.description.trim();
    if (description.isEmpty || description.length > 200) {
      return const Left(ValidationFailure('invalid_description'));
    }

    return _repository.createInstallments(
      accountId: params.accountId,
      categoryId: params.categoryId,
      totalCents: params.totalCents,
      installments: params.installments,
      description: description,
      purchaseAt: params.purchaseAt,
    );
  }
}