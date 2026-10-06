import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/data/datasources/account_remote_data_source.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AccountRemoteDataSource _remote;

  const AccountRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<AccountEntity>>> getAccounts(String workspaceId) {
    return _guard<List<AccountEntity>>(() => _remote.getAccounts(workspaceId));
  }

  @override
  Future<Either<Failure, List<AccountEntity>>> getArchivedAccounts(
    String workspaceId,
  ) {
    return _guard<List<AccountEntity>>(
      () => _remote.getArchivedAccounts(workspaceId),
    );
  }

  @override
  Future<Either<Failure, AccountEntity>> createAccount({
    required String workspaceId,
    required String name,
    required AccountType type,
    required String currency,
    required int openingBalanceCents,
  }) {
    return _guard<AccountEntity>(
      () => _remote.createAccount(
        workspaceId: workspaceId,
        name: name,
        type: type,
        currency: currency,
        openingBalanceCents: openingBalanceCents,
      ),
    );
  }

  @override
  Future<Either<Failure, AccountEntity>> updateAccount({
    required String accountId,
    required String name,
    int? openingBalanceCents,
  }) {
    return _guard<AccountEntity>(
      () => _remote.updateAccount(
        accountId: accountId,
        name: name,
        openingBalanceCents: openingBalanceCents,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> archiveAccount(String accountId) {
    return _guard<void>(() => _remote.archiveAccount(accountId));
  }

  @override
  Future<Either<Failure, void>> restoreAccount(String accountId) {
    return _guard<void>(() => _remote.restoreAccount(accountId));
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