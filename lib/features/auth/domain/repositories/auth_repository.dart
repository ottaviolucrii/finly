

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';

abstract class AuthRepository {

  /// Signs in a user with email and password.
  Future<Either<Failure, UserEntity>> signIn (String email, String password);

  /// Registers a new user and creates their first workspace
  Future<Either<Failure, UserEntity>> signUp ({
    required String email,
    required String password,
    required String taxId,
    required String name,
    required WorkspaceType initialWorkspace,
  }); 

  Future<Either<Failure, void>> signOut ();

  Future<Either<Failure, UserEntity>> switchWorkspace (String workspaceId);

}