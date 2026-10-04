import 'package:finly/features/accounts/data/datasources/account_remote_data_source.dart';
import 'package:finly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';
import 'package:finly/features/accounts/domain/usecases/archive_account_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_cubit.dart';
import 'package:finly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:finly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:finly/features/auth/domain/usecases/switch_workspace_use_case.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
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
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:finly/features/categories/data/datasources/category_remote_data_source.dart';
import 'package:finly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:finly/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:finly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finly/features/transactions/domain/usecases/confirm_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
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
    // accounts: use cases and presentation
    ..registerLazySingleton(() => GetAccountsUseCase(sl()))
    ..registerLazySingleton(() => CreateAccountUseCase(sl()))
    ..registerLazySingleton(() => ArchiveAccountUseCase(sl()))
    ..registerFactory(() => AccountsCubit(sl(), sl()))
    ..registerFactory(() => AccountFormCubit(sl()))
    // categories
    ..registerLazySingleton<CategoryRemoteDataSource>(
      () => CategoryRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetCategoriesUseCase(sl()))
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
    ..registerFactory(() => InvoicesCubit(sl()))
    ..registerFactory(() => InvoiceDetailCubit(sl()))
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
    ..registerFactory(() => TransactionFormCubit(sl()));
}