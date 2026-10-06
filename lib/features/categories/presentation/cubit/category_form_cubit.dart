import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/usecases/create_category_use_case.dart';
import 'package:finly/features/categories/domain/usecases/update_category_use_case.dart';
import 'package:finly/features/categories/presentation/cubit/category_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CategoryFormCubit extends Cubit<CategoryFormState> {
  final CreateCategoryUseCase _create;
  final UpdateCategoryUseCase _update;

  CategoryFormCubit({
    required CreateCategoryUseCase create,
    required UpdateCategoryUseCase update,
  })  : _create = create,
        _update = update,
        super(const CategoryFormState());

  Future<void> create({
    required String workspaceId,
    required String name,
    required CategoryKind kind,
    required String icon,
    required String colorHex,
  }) {
    return _run(
      () => _create(
        CreateCategoryParams(
          workspaceId: workspaceId,
          name: name,
          kind: kind,
          icon: icon,
          colorHex: colorHex,
        ),
      ),
    );
  }

  Future<void> update({
    required String categoryId,
    required String name,
    required String icon,
    required String colorHex,
  }) {
    return _run(
      () => _update(
        UpdateCategoryParams(
          categoryId: categoryId,
          name: name,
          icon: icon,
          colorHex: colorHex,
        ),
      ),
    );
  }

  Future<void> _run(
    Future<Either<Failure, CategoryEntity>> Function() action,
  ) async {
    if (state.status == CategoryFormStatus.submitting) return;

    emit(const CategoryFormState(status: CategoryFormStatus.submitting));
    final result = await action();
    emit(result.fold<CategoryFormState>(
      (failure) => CategoryFormState(
        status: CategoryFormStatus.failure,
        failure: failure,
      ),
      (_) => const CategoryFormState(status: CategoryFormStatus.success),
    ));
  }
}