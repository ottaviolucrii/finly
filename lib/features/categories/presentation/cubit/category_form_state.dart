import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum CategoryFormStatus { idle, submitting, success, failure }

class CategoryFormState extends Equatable {
  final CategoryFormStatus status;
  final Failure? failure;

  const CategoryFormState({
    this.status = CategoryFormStatus.idle,
    this.failure,
  });

  @override
  List<Object?> get props => [status, failure];
}