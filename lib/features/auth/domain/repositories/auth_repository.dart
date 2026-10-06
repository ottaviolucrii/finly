import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/sign_up_result.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  /// Signs in with e-mail and password.
  Future<Either<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  });

  /// Creates the account. The first workspace is created later, after the
  /// e-mail is verified (onboarding).
  Future<Either<Failure, SignUpResult>> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  /// Ends this device's session, or every session when [allDevices] is true.
  Future<Either<Failure, void>> signOut({bool allDevices = false});

  /// The user of the stored session, or null when nobody is signed in.
  Future<Either<Failure, UserEntity?>> getCurrentUser();

  /// Changes the active workspace. Moves to a workspace repository later.
  Future<Either<Failure, UserEntity>> switchWorkspace(String workspaceId);

  /// Checks [currentPassword] again, sets [newPassword], and signs the other
  /// devices out.
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Checks [password] again, then erases the user and everything they own.
  /// There is no way back.
  Future<Either<Failure, void>> deleteAccount({required String password});
}