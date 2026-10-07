import 'package:finly/features/budgets/data/datasources/budget_remote_data_source.dart';
import 'package:finly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/budgets/domain/usecases/save_budget_use_case.dart';
import 'package:finly/features/budgets/domain/usecases/stop_budget_use_case.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the budget classes.
void registerBudgetsModule(GetIt sl) {
  sl
    // data layer and use cases
    ..registerLazySingleton<BudgetRemoteDataSource>(
      () => BudgetRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<BudgetRepository>(() => BudgetRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetBudgetOverviewUseCase(sl(), sl()))
    ..registerLazySingleton(() => SaveBudgetUseCase(sl()))
    ..registerLazySingleton(() => StopBudgetUseCase(sl()))
    // presentation
    ..registerFactory(
      () => BudgetsCubit(getOverview: sl(), stopBudget: sl()),
    )
    ..registerFactory(() => BudgetFormCubit(sl()));
}
