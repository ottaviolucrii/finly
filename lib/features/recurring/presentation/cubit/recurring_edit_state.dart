import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum RecurringEditStatus { idle, submitting, success, failure }

class RecurringEditState extends Equatable {
  final RecurringEditStatus status;
  final Failure? failure;

  const RecurringEditState({
    this.status = RecurringEditStatus.idle,
    this.failure,
  });

  @override
  List<Object?> get props => [status, failure];
}