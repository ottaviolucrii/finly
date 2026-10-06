import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum RecurringDeleteStatus { idle, deleting, deleted, failure }

class RecurringDeleteState extends Equatable {
  final RecurringDeleteStatus status;
  final Failure? failure;

  const RecurringDeleteState({
    this.status = RecurringDeleteStatus.idle,
    this.failure,
  });

  @override
  List<Object?> get props => [status, failure];
}