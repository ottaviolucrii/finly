import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/categories/domain/usecases/set_category_archived_use_case.dart';
import 'package:finly/features/categories/presentation/cubit/categories_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CategoriesCubit extends Cubit<CategoriesState> {
  final GetAllCategoriesUseCase _getAll;
  final SetCategoryArchivedUseCase _setArchived;
  String? _workspaceId;

  CategoriesCubit({
    required GetAllCategoriesUseCase getAll,
    required SetCategoryArchivedUseCase setArchived,
  })  : _getAll = getAll,
        _setArchived = setArchived,
        super(const CategoriesState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old list on screen while reloading, to avoid flicker.
    emit(CategoriesState(
      status: CategoriesStatus.loading,
      categories: state.categories,
    ));

    final result = await _getAll(workspaceId);
    emit(result.fold<CategoriesState>(
      (failure) => CategoriesState(
        status: CategoriesStatus.failure,
        failure: failure,
      ),
      (categories) => CategoriesState(
        status: CategoriesStatus.loaded,
        categories: categories,
      ),
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }

  /// Archives a category, or restores an archived one, then reloads.
  Future<void> setArchived(CategoryEntity category, {required bool archived}) async {
    final result = await _setArchived(
      SetCategoryArchivedParams(categoryId: category.id, archived: archived),
    );
    await result.fold<Future<void>>(
      (failure) async => emit(CategoriesState(
        status: CategoriesStatus.loaded,
        categories: state.categories,
        actionFailure: failure,
      )),
      (_) => reload(),
    );
  }
}