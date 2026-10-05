import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum CardFormStatus { idle, submitting, success, failure }

class CardFormState extends Equatable {
  final CardFormStatus status;
  final Failure? failure;

  /// The account id of the card that was created.
  final String? accountId;

  const CardFormState({
    this.status = CardFormStatus.idle,
    this.failure,
    this.accountId,
  });

  @override
  List<Object?> get props => [status, failure, accountId];
}