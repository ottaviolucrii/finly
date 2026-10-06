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
import 'package:get_it/get_it.dart';

/// Registers the account classes.
void registerAccountsModule(GetIt sl) {
  sl
    // data layer
    ..registerLazySingleton<AccountRemoteDataSource>(
      () => AccountRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(sl()),
    )
    // use cases
    ..registerLazySingleton(() => GetAccountsUseCase(sl()))
    ..registerLazySingleton(() => GetArchivedAccountsUseCase(sl()))
    ..registerLazySingleton(() => CreateAccountUseCase(sl()))
    ..registerLazySingleton(() => UpdateAccountUseCase(sl()))
    ..registerLazySingleton(() => ArchiveAccountUseCase(sl()))
    ..registerLazySingleton(() => RestoreAccountUseCase(sl()))
    // presentation
    ..registerFactory(() => AccountsCubit(sl(), sl()))
    ..registerFactory(
      () => ArchivedAccountsCubit(getArchived: sl(), restore: sl()),
    )
    ..registerFactory(() => AccountFormCubit(sl()))
    ..registerFactory(() => AccountEditCubit(sl()));
}