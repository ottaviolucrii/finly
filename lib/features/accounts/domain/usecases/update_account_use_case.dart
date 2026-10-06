import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';

class UpdateAccountParams extends Equatable {
  final String accountId;
  final String name;

  /// Null leaves the opening balance as it is (credit cards).
  final int? openingBalanceCents;

  const UpdateAccountParams({
    required this.accountId,
    required this.name,
    this.openingBalanceCents,
  });

  @override
  List<Object?> get props => [accountId, name, openingBalanceCents];
}

/// Renames an account and, optionally, corrects its opening balance. The type
/// and the currency never change.
class UpdateAccountUseCase
    implements UseCase<AccountEntity, UpdateAccountParams> {
  final AccountRepository _repository;

  const UpdateAccountUseCase(this._repository);

  @override
  Future<Either<Failure, AccountEntity>> call(
    UpdateAccountParams params,
  ) async {
    if (params.accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    final name = params.name.trim();
    if (name.isEmpty || name.length > 80) {
      return const Left(ValidationFailure('invalid_account_name'));
    }

    return _repository.updateAccount(
      accountId: params.accountId,
      name: name,
      openingBalanceCents: params.openingBalanceCents,
    );
  }
}