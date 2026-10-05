import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';

class CreateCardParams extends Equatable {
  final String workspaceId;
  final String name;
  final String currency;
  final int limitCents;
  final int closingDay;
  final int dueDay;

  const CreateCardParams({
    required this.workspaceId,
    required this.name,
    required this.currency,
    required this.limitCents,
    required this.closingDay,
    required this.dueDay,
  });

  @override
  List<Object?> get props =>
      [workspaceId, name, currency, limitCents, closingDay, dueDay];
}

/// Returns the id of the card's account.
class CreateCardUseCase implements UseCase<String, CreateCardParams> {
  final CardRepository _repository;

  const CreateCardUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(CreateCardParams params) async {
    final name = params.name.trim();
    if (name.isEmpty || name.length > 80) {
      return const Left(ValidationFailure('invalid_account_name'));
    }
    if (!CreateAccountUseCase.supportedCurrencies.contains(params.currency)) {
      return const Left(ValidationFailure('invalid_currency'));
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

    return _repository.createCard(
      workspaceId: params.workspaceId,
      name: name,
      currency: params.currency,
      limitCents: params.limitCents,
      closingDay: params.closingDay,
      dueDay: params.dueDay,
    );
  }
}