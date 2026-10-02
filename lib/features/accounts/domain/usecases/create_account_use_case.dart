import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';

class CreateAccountParams extends Equatable {
  final String workspaceId;
  final String name;
  final AccountType type;
  final String currency;
  final int openingBalanceCents;

  const CreateAccountParams({
    required this.workspaceId,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalanceCents,
  });

  @override
  List<Object?> get props =>
      [workspaceId, name, type, currency, openingBalanceCents];
}

class CreateAccountUseCase
    implements UseCase<AccountEntity, CreateAccountParams> {
  final AccountRepository _repository;

  const CreateAccountUseCase(this._repository);

  /// Currencies supported today (SRS FR-M01 asks for BRL, USD and EUR).
  static const supportedCurrencies = {'BRL', 'USD', 'EUR'};

  @override
  Future<Either<Failure, AccountEntity>> call(CreateAccountParams params) async {
    final name = params.name.trim();
    if (name.isEmpty || name.length > 80) {
      return const Left(ValidationFailure('invalid_account_name'));
    }
    if (!supportedCurrencies.contains(params.currency)) {
      return const Left(ValidationFailure('invalid_currency'));
    }
    // Cards need a limit, a closing day and a due day: they get their own flow.
    if (params.type == AccountType.creditCard) {
      return const Left(ValidationFailure('credit_card_needs_settings'));
    }

    return _repository.createAccount(
      workspaceId: params.workspaceId,
      name: name,
      type: params.type,
      currency: params.currency,
      openingBalanceCents: params.openingBalanceCents,
    );
  }
}