import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum BudgetFormStatus { idle, submitting, success, failure }

class BudgetFormState extends Equatable {
  final BudgetFormStatus status;
  final Failure? failure;

  const BudgetFormState({this.status = BudgetFormStatus.idle, this.failure});

  @override
  List<Object?> get props => [status, failure];
}