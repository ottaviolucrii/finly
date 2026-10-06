import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum TransactionEditStatus { idle, submitting, success, failure }

class TransactionEditState extends Equatable {
  final TransactionEditStatus status;
  final Failure? failure;

  const TransactionEditState({
    this.status = TransactionEditStatus.idle,
    this.failure,
  });

  @override
  List<Object?> get props => [status, failure];
}