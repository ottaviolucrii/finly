import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum CardArchiveStatus { idle, archiving, archived, failure }

class CardArchiveState extends Equatable {
  final CardArchiveStatus status;
  final Failure? failure;

  const CardArchiveState({this.status = CardArchiveStatus.idle, this.failure});

  @override
  List<Object?> get props => [status, failure];
}