import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';

enum OnboardingStatus { idle, submitting, success, failure }

class OnboardingState extends Equatable {
  /// Null while the user is still choosing Personal or Business.
  final WorkspaceType? type;
  final OnboardingStatus status;
  final Failure? failure;
  final WorkspaceEntity? workspace;

  const OnboardingState({
    this.type,
    this.status = OnboardingStatus.idle,
    this.failure,
    this.workspace,
  });

  @override
  List<Object?> get props => [type, status, failure, workspace];
}