import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum RecurringFormStatus { idle, submitting, success, failure }

class RecurringFormState extends Equatable {
  final RecurringFormStatus status;
  final Failure? failure;

  const RecurringFormState({
    this.status = RecurringFormStatus.idle,
    this.failure,
  });

  @override
  List<Object?> get props => [status, failure];
}