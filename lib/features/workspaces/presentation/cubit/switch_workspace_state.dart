import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum SwitchWorkspaceStatus { idle, switching, success, failure }

class SwitchWorkspaceState extends Equatable {
  final SwitchWorkspaceStatus status;
  final Failure? failure;

  const SwitchWorkspaceState({
    this.status = SwitchWorkspaceStatus.idle,
    this.failure,
  });

  @override
  List<Object?> get props => [status, failure];
}