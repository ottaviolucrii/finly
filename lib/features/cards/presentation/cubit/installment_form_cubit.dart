import 'package:finly/features/cards/domain/usecases/create_installments_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/installment_form_state.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InstallmentFormCubit extends Cubit<InstallmentFormState> {
  final GetCategoriesUseCase _getCategories;
  final CreateInstallmentsUseCase _createInstallments;

  InstallmentFormCubit({
    required GetCategoriesUseCase getCategories,
    required CreateInstallmentsUseCase createInstallments,
  })  : _getCategories = getCategories,
        _createInstallments = createInstallments,
        super(const InstallmentFormState());

  /// A purchase is an expense, so only expense categories are offered.
  Future<void> loadCategories(String workspaceId) async {
    emit(const InstallmentFormState(status: InstallmentFormStatus.loading));

    final result = await _getCategories(workspaceId);
    emit(result.fold<InstallmentFormState>(
      (failure) => InstallmentFormState(
        status: InstallmentFormStatus.loadFailed,
        failure: failure,
      ),
      (categories) => InstallmentFormState(
        status: InstallmentFormStatus.ready,
        categories: categories
            .where((category) => category.kind == CategoryKind.expense)
            .toList(),
      ),
    ));
  }

  Future<void> submit({
    required String accountId,
    String? categoryId,
    required int totalCents,
    required int installments,
    required String description,
    required DateTime purchaseAt,
  }) async {
    if (state.status == InstallmentFormStatus.submitting) return;

    emit(InstallmentFormState(
      status: InstallmentFormStatus.submitting,
      categories: state.categories,
    ));
    final result = await _createInstallments(
      CreateInstallmentsParams(
        accountId: accountId,
        categoryId: categoryId,
        totalCents: totalCents,
        installments: installments,
        description: description,
        purchaseAt: purchaseAt,
      ),
    );
    emit(result.fold<InstallmentFormState>(
      (failure) => InstallmentFormState(
        status: InstallmentFormStatus.failure,
        categories: state.categories,
        failure: failure,
      ),
      (_) => InstallmentFormState(
        status: InstallmentFormStatus.success,
        categories: state.categories,
      ),
    ));
  }
}