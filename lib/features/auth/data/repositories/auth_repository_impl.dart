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

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error, not Exception) are not caught on purpose.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } on Exception catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}