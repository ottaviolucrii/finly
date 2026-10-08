import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:finly/features/tax_reserve/domain/usecases/get_tax_categories_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/set_category_tax_use_case.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Which expense categories count as a tax in the tax reserve.
class TaxCategoriesCubit extends Cubit<TaxCategoriesState> {
  final GetTaxCategoriesUseCase _getCategories;
  final SetCategoryTaxUseCase _setCategoryTax;
  String? _workspaceId;

  TaxCategoriesCubit({
    required GetTaxCategoriesUseCase getCategories,
    required SetCategoryTaxUseCase setCategoryTax,
  })  : _getCategories = getCategories,
        _setCategoryTax = setCategoryTax,
        super(const TaxCategoriesState());

  Future<void> load(String workspaceId) {
    _workspaceId = workspaceId;
    return reload();
  }

  Future<void> reload() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;

    emit(TaxCategoriesState(
      status: TaxCategoriesStatus.loading,
      categories: state.categories,
      changes: state.changes,
    ));

    final result = await _getCategories(workspaceId);
    if (isClosed) return;

    emit(result.fold<TaxCategoriesState>(
      (failure) => TaxCategoriesState(
        status: TaxCategoriesStatus.failure,
        categories: state.categories,
        failure: failure,
        changes: state.changes,
      ),
      (categories) => TaxCategoriesState(
        status: TaxCategoriesStatus.loaded,
        categories: categories,
        changes: state.changes,
      ),
    ));
  }

  /// Marks a category as a tax, or takes the mark off. The switch moves at once;
  /// if the change is refused it goes back and [TaxCategoriesState.saveFailure]
  /// says why.
  Future<void> setTax(String categoryId, {required bool isTax}) async {
    if (state.savingId != null) return;

    final before = state.categories;
    final index = before.indexWhere((category) => category.id == categoryId);
    if (index < 0 || before[index].isTax == isTax) return;

    final after = [...before]..[index] = before[index].withTax(isTax);
    emit(TaxCategoriesState(
      status: TaxCategoriesStatus.loaded,
      categories: after,
      savingId: categoryId,
      changes: state.changes,
    ));

    final result = await _setCategoryTax(
      SetCategoryTaxParams(categoryId: categoryId, isTax: isTax),
    );
    if (isClosed) return;

    emit(result.fold<TaxCategoriesState>(
      (failure) => TaxCategoriesState(
        status: TaxCategoriesStatus.loaded,
        categories: before,
        saveFailure: failure,
        changes: state.changes,
      ),
      (_) => TaxCategoriesState(
        status: TaxCategoriesStatus.loaded,
        categories: after,
        changes: state.changes + 1,
      ),
    ));
  }
}
