import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/usecases/generate_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/get_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/set_recurring_active_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecurringCubit extends Cubit<RecurringState> {
  final GetRecurringUseCase _getRecurring;
  final GenerateRecurringUseCase _generateRecurring;
  final GetAccountsUseCase _getAccounts;
  final GetCategoriesUseCase _getCategories;
  final SetRecurringActiveUseCase _setActive;
  String? _workspaceId;

  RecurringCubit({
    required GetRecurringUseCase getRecurring,
    required GenerateRecurringUseCase generateRecurring,
    required GetAccountsUseCase getAccounts,
    required GetCategoriesUseCase getCategories,
    required SetRecurringActiveUseCase setActive,
  })  : _getRecurring = getRecurring,
        _generateRecurring = generateRecurring,
        _getAccounts = getAccounts,
        _getCategories = getCategories,
        _setActive = setActive,
        super(const RecurringState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old data on screen while reloading, to avoid flicker.
    emit(RecurringState(
      status: RecurringStatus.loading,
      items: state.items,
      accounts: state.accounts,
      categories: state.categories,
    ));

    // Creates the pending transactions that are due. If it fails, the list
    // still loads: the occurrences are created the next time.
    await _generateRecurring(const NoParams());

    final items = await _getRecurring(workspaceId);
    final accounts = await _getAccounts(workspaceId);
    final categories = await _getCategories(workspaceId);

    Failure? failure;
    var itemList = const <RecurringEntity>[];
    var accountList = const <AccountEntity>[];
    var categoryList = const <CategoryEntity>[];

    items.fold((f) {
      failure ??= f;
    }, (value) {
      itemList = value;
    });
    accounts.fold((f) {
      failure ??= f;
    }, (value) {
      accountList = value;
    });
    categories.fold((f) {
      failure ??= f;
    }, (value) {
      categoryList = value;
    });

    final loadFailure = failure;
    if (loadFailure != null) {
      emit(RecurringState(
        status: RecurringStatus.failure,
        failure: loadFailure,
      ));
      return;
    }

    emit(RecurringState(
      status: RecurringStatus.loaded,
      items: itemList,
      accounts: accountList,
      categories: categoryList,
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }

  /// Pauses a running item or resumes a paused one, then reloads.
  Future<void> toggleActive(RecurringEntity item) async {
    final result = await _setActive(
      SetRecurringActiveParams(id: item.id, active: !item.isActive),
    );
    await result.fold<Future<void>>(
      (failure) async => emit(RecurringState(
        status: RecurringStatus.loaded,
        items: state.items,
        accounts: state.accounts,
        categories: state.categories,
        actionFailure: failure,
      )),
      (_) => reload(),
    );
  }
}