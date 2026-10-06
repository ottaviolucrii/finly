import 'package:finly/features/accounts/data/datasources/account_remote_data_source.dart';
import 'package:finly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';
import 'package:finly/features/accounts/domain/usecases/archive_account_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/get_archived_accounts_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/restore_account_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/update_account_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/archived_accounts_cubit.dart';
import 'package:finly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:finly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:finly/features/auth/domain/usecases/switch_workspace_use_case.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/budgets/data/datasources/budget_remote_data_source.dart';
import 'package:finly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finly/features/budgets/domain/usecases/delete_budget_use_case.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/budgets/domain/usecases/save_budget_use_case.dart';
import 'package:finly/features/budgets/domain/usecases/stop_budget_use_case.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_cubit.dart';
import 'package:finly/features/cards/data/datasources/card_remote_data_source.dart';
import 'package:finly/features/cards/data/repositories/card_repository_impl.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/cards/domain/usecases/create_card_use_case.dart';
import 'package:finly/features/cards/domain/usecases/create_installments_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_cards_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoice_transactions_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/domain/usecases/pay_invoice_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/cards_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/installment_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:finly/features/categories/data/datasources/category_remote_data_source.dart';
import 'package:finly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/categories/domain/usecases/create_category_use_case.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:finly/features/categories/domain/usecases/set_category_archived_use_case.dart';
import 'package:finly/features/categories/domain/usecases/update_category_use_case.dart';
import 'package:finly/features/categories/presentation/cubit/categories_cubit.dart';
import 'package:finly/features/categories/presentation/cubit/category_form_cubit.dart';
import 'package:finly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:finly/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/dashboard/domain/usecases/get_dashboard_use_case.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/recurring/data/datasources/recurring_remote_data_source.dart';
import 'package:finly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finly/features/recurring/domain/usecases/create_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/generate_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/get_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/set_recurring_active_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_form_cubit.dart';
import 'package:finly/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:finly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finly/features/transactions/domain/usecases/confirm_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/update_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_edit_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_cubit.dart';
import 'package:finly/features/transfers/data/datasources/transfer_remote_data_source.dart';
import 'package:finly/features/transfers/data/repositories/transfer_repository_impl.dart';
import 'package:finly/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:finly/features/transfers/domain/usecases/create_transfer_use_case.dart';
import 'package:finly/features/transfers/domain/usecases/delete_transfer_use_case.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_cubit.dart';
import 'package:finly/features/workspaces/data/datasources/workspace_remote_data_source.dart';
import 'package:finly/features/workspaces/data/repositories/workspace_repository_impl.dart';
import 'package:finly/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:finly/features/workspaces/domain/usecases/create_workspace_use_case.dart';
import 'package:finly/features/workspaces/presentation/cubit/onboarding_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt sl = GetIt.instance;

/// Registers everything the app needs. Call once, after Supabase.initialize.
void configureDependencies() {
  sl
    ..registerLazySingleton<SupabaseClient>(() => Supabase.instance.client)
    // auth: data layer
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()))
    // auth: use cases
    ..registerLazySingleton(() => SignInUseCase(sl()))
    ..registerLazySingleton(() => SignUpUseCase(sl()))
    ..registerLazySingleton(() => SignOutUseCase(sl()))
    ..registerLazySingleton(() => GetCurrentUserUseCase(sl()))
    ..registerLazySingleton(() => SwitchWorkspaceUseCase(sl()))
    // auth: presentation (a new bloc each time it is requested)
    ..registerFactory(
      () => AuthBloc(
        signIn: sl(),
        signUp: sl(),
        signOut: sl(),
        getCurrentUser: sl(),
      ),
    )
    // workspaces: data layer
    ..registerLazySingleton<WorkspaceRemoteDataSource>(
      () => WorkspaceRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<WorkspaceRepository>(
      () => WorkspaceRepositoryImpl(sl()),
    )
    // workspaces: use cases and presentation
    ..registerLazySingleton(() => CreateWorkspaceUseCase(sl()))
    ..registerFactory(() => OnboardingCubit(sl()))
    ..registerFactory(() => SwitchWorkspaceCubit(sl()))
    // accounts: data layer
    ..registerLazySingleton<AccountRemoteDataSource>(
      () => AccountRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(sl()),
    )
    // accounts: use cases
    ..registerLazySingleton(() => GetAccountsUseCase(sl()))
    ..registerLazySingleton(() => GetArchivedAccountsUseCase(sl()))
    ..registerLazySingleton(() => CreateAccountUseCase(sl()))
    ..registerLazySingleton(() => UpdateAccountUseCase(sl()))
    ..registerLazySingleton(() => ArchiveAccountUseCase(sl()))
    ..registerLazySingleton(() => RestoreAccountUseCase(sl()))
    // accounts: presentation
    ..registerFactory(() => AccountsCubit(sl(), sl()))
    ..registerFactory(
      () => ArchivedAccountsCubit(getArchived: sl(), restore: sl()),
    )
    ..registerFactory(() => AccountFormCubit(sl()))
    ..registerFactory(() => AccountEditCubit(sl()))
    // categories: data layer and use cases
    ..registerLazySingleton<CategoryRemoteDataSource>(
      () => CategoryRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetCategoriesUseCase(sl()))
    ..registerLazySingleton(() => GetAllCategoriesUseCase(sl()))
    ..registerLazySingleton(() => CreateCategoryUseCase(sl()))
    ..registerLazySingleton(() => UpdateCategoryUseCase(sl()))
    ..registerLazySingleton(() => SetCategoryArchivedUseCase(sl()))
    // categories: presentation
    ..registerFactory(
      () => CategoriesCubit(getAll: sl(), setArchived: sl()),
    )
    ..registerFactory(
      () => CategoryFormCubit(create: sl(), update: sl()),
    )
    // transactions: data layer
    ..registerLazySingleton<TransactionRemoteDataSource>(
      () => TransactionRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(sl()),
    )
    // transactions: use cases
    ..registerLazySingleton(() => GetTransactionsUseCase(sl()))
    ..registerLazySingleton(() => CreateTransactionUseCase(sl()))
    ..registerLazySingleton(() => UpdateTransactionUseCase(sl()))
    ..registerLazySingleton(() => ConfirmTransactionUseCase(sl()))
    ..registerLazySingleton(() => DeleteTransactionUseCase(sl()))
    ..registerLazySingleton(() => RestoreTransactionUseCase(sl()))
    // transfers
    ..registerLazySingleton<TransferRemoteDataSource>(
      () => TransferRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TransferRepository>(
      () => TransferRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => CreateTransferUseCase(sl()))
    ..registerLazySingleton(() => DeleteTransferUseCase(sl()))
    ..registerFactory(() => TransferFormCubit(sl(), sl()))
    // cards: data layer and use cases
    ..registerLazySingleton<CardRemoteDataSource>(
      () => CardRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<CardRepository>(() => CardRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetCardsUseCase(sl()))
    ..registerLazySingleton(() => CreateCardUseCase(sl()))
    ..registerLazySingleton(() => GetInvoicesUseCase(sl()))
    ..registerLazySingleton(() => GetInvoiceTransactionsUseCase(sl()))
    ..registerLazySingleton(() => CreateInstallmentsUseCase(sl()))
    ..registerLazySingleton(() => PayInvoiceUseCase(sl()))
    // cards: presentation
    ..registerFactory(() => CardsCubit(sl()))
    ..registerFactory(() => CardFormCubit(sl()))
    ..registerFactory(
      () => InvoicesCubit(getInvoices: sl(), getCards: sl()),
    )
    ..registerFactory(
      () => InvoiceDetailCubit(
        getTransactions: sl(),
        getInvoices: sl(),
        getAccounts: sl(),
        payInvoice: sl(),
      ),
    )
    ..registerFactory(
      () => InstallmentFormCubit(getCategories: sl(), createInstallments: sl()),
    )
    // budgets: data layer and use cases
    ..registerLazySingleton<BudgetRemoteDataSource>(
      () => BudgetRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<BudgetRepository>(() => BudgetRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetBudgetOverviewUseCase(sl(), sl()))
    ..registerLazySingleton(() => SaveBudgetUseCase(sl()))
    ..registerLazySingleton(() => DeleteBudgetUseCase(sl()))
    ..registerLazySingleton(() => StopBudgetUseCase(sl()))
    // budgets: presentation
    ..registerFactory(
      () => BudgetsCubit(getOverview: sl(), stopBudget: sl()),
    )
    ..registerFactory(() => BudgetFormCubit(sl()))
    // recurring: data layer and use cases
    ..registerLazySingleton<RecurringRemoteDataSource>(
      () => RecurringRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<RecurringRepository>(
      () => RecurringRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetRecurringUseCase(sl()))
    ..registerLazySingleton(() => CreateRecurringUseCase(sl()))
    ..registerLazySingleton(() => SetRecurringActiveUseCase(sl()))
    ..registerLazySingleton(() => GenerateRecurringUseCase(sl()))
    // recurring: presentation
    ..registerFactory(
      () => RecurringCubit(
        getRecurring: sl(),
        generateRecurring: sl(),
        getAccounts: sl(),
        getCategories: sl(),
        setActive: sl(),
      ),
    )
    ..registerFactory(() => RecurringFormCubit(sl()))
    // dashboard
    ..registerLazySingleton<DashboardRemoteDataSource>(
      () => DashboardRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetDashboardUseCase(sl(), sl(), sl()))
    ..registerFactory(() => DashboardCubit(sl()))
    // transactions: presentation
    ..registerFactory(
      () => TransactionsCubit(
        getTransactions: sl(),
        getAccounts: sl(),
        getCategories: sl(),
        confirmTransaction: sl(),
        deleteTransaction: sl(),
        restoreTransaction: sl(),
        deleteTransfer: sl(),
      ),
    )
    ..registerFactory(() => TransactionFormCubit(sl()))
    ..registerFactory(() => TransactionEditCubit(sl()));
}