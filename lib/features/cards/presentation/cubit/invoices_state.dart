import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';

enum InvoicesStatus { initial, loading, loaded, failure }

class InvoicesState extends Equatable {
  final InvoicesStatus status;
  final List<InvoiceEntity> invoices;
  final Failure? failure;

  const InvoicesState({
    this.status = InvoicesStatus.initial,
    this.invoices = const [],
    this.failure,
  });

  @override
  List<Object?> get props => [status, invoices, failure];
}