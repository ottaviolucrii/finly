import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';

class SetCategoryArchivedParams extends Equatable {
  final String categoryId;
  final bool archived;

  const SetCategoryArchivedParams({
    required this.categoryId,
    required this.archived,
  });

  @override
  List<Object?> get props => [categoryId, archived];
}

/// Archives a category, or restores an archived one.
class SetCategoryArchivedUseCase
    implements UseCase<void, SetCategoryArchivedParams> {
  final CategoryRepository _repository;

  const SetCategoryArchivedUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(SetCategoryArchivedParams params) async {
    if (params.categoryId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_category'));
    }
    return _repository.setArchived(params.categoryId, archived: params.archived);
  }
}