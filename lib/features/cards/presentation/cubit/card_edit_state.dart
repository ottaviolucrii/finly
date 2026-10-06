import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum CardEditStatus { idle, submitting, success, failure }

class CardEditState extends Equatable {
  final CardEditStatus status;
  final Failure? failure;

  const CardEditState({this.status = CardEditStatus.idle, this.failure});

  @override
  List<Object?> get props => [status, failure];
}