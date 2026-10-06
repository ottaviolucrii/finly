import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';

class UpdateCardParams extends Equatable {
  final String accountId;
  final String name;
  final int limitCents;
  final int closingDay;
  final int dueDay;

  const UpdateCardParams({
    required this.accountId,
    required this.name,
    required this.limitCents,
    required this.closingDay,
    required this.dueDay,
  });

  @override
  List<Object?> get props =>
      [accountId, name, limitCents, closingDay, dueDay];
}

/// Changes a card's name, limit and closing and due days.
class UpdateCardUseCase implements UseCase<void, UpdateCardParams> {
  final CardRepository _repository;

  const UpdateCardUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(UpdateCardParams params) async {
    if (params.accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    final name = params.name.trim();
    if (name.isEmpty || name.length > 80) {
      return const Left(ValidationFailure('invalid_account_name'));
    }
    if (params.limitCents <= 0) {
      return const Left(ValidationFailure('invalid_limit'));
    }
    // Days beyond a month's length move to that month's last day (BR-12).
    if (params.closingDay < 1 ||
        params.closingDay > 31 ||
        params.dueDay < 1 ||
        params.dueDay > 31) {
      return const Left(ValidationFailure('invalid_day'));
    }

    return _repository.updateCard(
      accountId: params.accountId,
      name: name,
      limitCents: params.limitCents,
      closingDay: params.closingDay,
      dueDay: params.dueDay,
    );
  }
}