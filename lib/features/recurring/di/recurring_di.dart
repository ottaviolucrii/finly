import 'package:finly/features/recurring/data/datasources/recurring_remote_data_source.dart';
import 'package:finly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finly/features/recurring/domain/usecases/create_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/delete_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/generate_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/get_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/set_recurring_active_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/update_recurring_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_delete_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_edit_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_form_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the recurring bill classes.
void registerRecurringModule(GetIt sl) {
  sl
    // data layer and use cases
    ..registerLazySingleton<RecurringRemoteDataSource>(
      () => RecurringRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<RecurringRepository>(
      () => RecurringRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetRecurringUseCase(sl()))
    ..registerLazySingleton(() => CreateRecurringUseCase(sl()))
    ..registerLazySingleton(() => UpdateRecurringUseCase(sl()))
    ..registerLazySingleton(() => DeleteRecurringUseCase(sl()))
    ..registerLazySingleton(() => SetRecurringActiveUseCase(sl()))
    ..registerLazySingleton(() => GenerateRecurringUseCase(sl()))
    // presentation
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
    ..registerFactory(() => RecurringEditCubit(sl()))
    ..registerFactory(() => RecurringDeleteCubit(sl()));
}