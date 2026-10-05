import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';

enum InstallmentFormStatus {
  /// Loading the expense categories.
  loading,
  loadFailed,
  ready,
  submitting,
  success,
  failure,
}

class InstallmentFormState extends Equatable {
  final InstallmentFormStatus status;

  /// Expense categories of the workspace.
  final List<CategoryEntity> categories;
  final Failure? failure;

  const InstallmentFormState({
    this.status = InstallmentFormStatus.loading,
    this.categories = const [],
    this.failure,
  });

  @override
  List<Object?> get props => [status, categories, failure];
}