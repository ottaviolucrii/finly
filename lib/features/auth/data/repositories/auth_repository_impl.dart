import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:finly/features/auth/domain/entities/sign_up_result.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;

  const AuthRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  }) {
    return _guard<UserEntity>(
      () => _remote.signIn(email: email, password: password),
    );
  }

  @override
  Future<Either<Failure, SignUpResult>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _guard<SignUpResult>(
      () => _remote.signUp(email: email, password: password, fullName: fullName),
    );
  }

  @override
  Future<Either<Failure, void>> signOut({bool allDevices = false}) {
    return _guard<void>(() => _remote.signOut(allDevices: allDevices));
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() {
    return _guard<UserEntity?>(() => _remote.currentUser());
  }

  @override
  Future<Either<Failure, UserEntity>> switchWorkspace(String workspaceId) {
    return _guard<UserEntity>(() => _remote.switchWorkspace(workspaceId));
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _guard<void>(
      () => _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> deleteAccount({required String password}) {
    return _guard<void>(() => _remote.deleteAccount(password: password));
  }

  @override
  Future<Either<Failure, void>> requestPasswordReset({required String email}) {
    return _guard<void>(() => _remote.requestPasswordReset(email: email));
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _guard<void>(
      () => _remote.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      ),
    );
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