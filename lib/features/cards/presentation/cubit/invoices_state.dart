import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';

enum InvoicesStatus { initial, loading, loaded, failure }

class InvoicesState extends Equatable {
  final InvoicesStatus status;
  final List<InvoiceEntity> invoices;

  /// The card with its used limit, refreshed on every load (purchases and
  /// payments change it).
  final CreditCardEntity? card;
  final Failure? failure;

  const InvoicesState({
    this.status = InvoicesStatus.initial,
    this.invoices = const [],
    this.card,
    this.failure,
  });

  @override
  List<Object?> get props => [status, invoices, card, failure];
}