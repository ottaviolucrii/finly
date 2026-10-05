import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';

enum SwitchWorkspaceStatus { idle, switching, success, failure }

class SwitchWorkspaceState extends Equatable {
  final SwitchWorkspaceStatus status;
  final Failure? failure;

  /// The user with the new active workspace, set on success.
  final UserEntity? user;

  const SwitchWorkspaceState({
    this.status = SwitchWorkspaceStatus.idle,
    this.failure,
    this.user,
  });

  @override
  List<Object?> get props => [status, failure, user];
}