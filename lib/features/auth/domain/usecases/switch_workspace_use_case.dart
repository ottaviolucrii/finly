import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

class SwitchWorkspaceParams extends Equatable {
  final String workspaceId;

  const SwitchWorkspaceParams({required this.workspaceId});

  @override
  List<Object?> get props => [workspaceId];
}

/// Makes another workspace the active one. The database checks that the
/// workspace belongs to the signed-in user.
class SwitchWorkspaceUseCase
    implements UseCase<UserEntity, SwitchWorkspaceParams> {
  final AuthRepository _repository;

  const SwitchWorkspaceUseCase(this._repository);

  @override
  Future<Either<Failure, UserEntity>> call(SwitchWorkspaceParams params) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.switchWorkspace(params.workspaceId);
  }
}