import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';

abstract class AccountRepository {
  /// Active (not archived) accounts of a workspace, with their balances.
  Future<Either<Failure, List<AccountEntity>>> getAccounts(String workspaceId);

  Future<Either<Failure, AccountEntity>> createAccount({
    required String workspaceId,
    required String name,
    required AccountType type,
    required String currency,
    required int openingBalanceCents,
  });

  /// Hides the account but keeps its history.
  Future<Either<Failure, void>> archiveAccount(String accountId);
}