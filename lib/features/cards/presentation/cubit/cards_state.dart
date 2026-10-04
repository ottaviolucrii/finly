import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';

enum CardsStatus { initial, loading, loaded, failure }

class CardsState extends Equatable {
  final CardsStatus status;
  final List<CreditCardEntity> cards;
  final Failure? failure;

  const CardsState({
    this.status = CardsStatus.initial,
    this.cards = const [],
    this.failure,
  });

  @override
  List<Object?> get props => [status, cards, failure];
}