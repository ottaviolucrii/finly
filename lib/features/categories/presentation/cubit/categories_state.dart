import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';

enum CategoriesStatus { initial, loading, loaded, failure }

class CategoriesState extends Equatable {
  final CategoriesStatus status;

  /// Every category of the workspace, archived ones included.
  final List<CategoryEntity> categories;

  /// Why loading failed (shown full screen with a retry button).
  final Failure? failure;

  /// Why archiving or restoring failed (shown as a message).
  final Failure? actionFailure;

  const CategoriesState({
    this.status = CategoriesStatus.initial,
    this.categories = const [],
    this.failure,
    this.actionFailure,
  });

  @override
  List<Object?> get props => [status, categories, failure, actionFailure];
}