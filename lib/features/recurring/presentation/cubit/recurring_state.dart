import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';

enum RecurringStatus { initial, loading, loaded, failure }

class RecurringState extends Equatable {
  final RecurringStatus status;
  final List<RecurringEntity> items;

  /// Loaded together with the items: the list shows account names, and the
  /// form needs both lists.
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  /// Why loading failed (shown full screen with a retry button).
  final Failure? failure;

  /// Why pausing or resuming failed (shown as a message).
  final Failure? actionFailure;

  const RecurringState({
    this.status = RecurringStatus.initial,
    this.items = const [],
    this.accounts = const [],
    this.categories = const [],
    this.failure,
    this.actionFailure,
  });

  @override
  List<Object?> get props =>
      [status, items, accounts, categories, failure, actionFailure];
}