import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';

abstract class AccountRepository {
  /// Active (not archived) accounts of a workspace, with their balances.
  Future<Either<Failure, List<AccountEntity>>> getAccounts(String workspaceId);

  /// Archived accounts of a workspace, most recently archived first.
  Future<Either<Failure, List<AccountEntity>>> getArchivedAccounts(
    String workspaceId,
  );

  Future<Either<Failure, AccountEntity>> createAccount({
    required String workspaceId,
    required String name,
    required AccountType type,
    required String currency,
    required int openingBalanceCents,
  });

  /// Changes the name and, when [openingBalanceCents] is given, the opening
  /// balance. The type and the currency never change.
  Future<Either<Failure, AccountEntity>> updateAccount({
    required String accountId,
    required String name,
    int? openingBalanceCents,
  });

  /// Hides the account but keeps its history.
  Future<Either<Failure, void>> archiveAccount(String accountId);

  /// Brings an archived account back. Fails when another active account has
  /// the same name.
  Future<Either<Failure, void>> restoreAccount(String accountId);
}