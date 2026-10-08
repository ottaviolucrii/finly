import 'package:finly/features/goals/data/datasources/goal_remote_data_source.dart';
import 'package:finly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:finly/features/goals/domain/repositories/goal_repository.dart';
import 'package:finly/features/goals/domain/usecases/archive_goal_use_case.dart';
import 'package:finly/features/goals/domain/usecases/get_goal_progress_use_case.dart';
import 'package:finly/features/goals/domain/usecases/save_goal_use_case.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goals_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the savings goals. The form reads the accounts with the use case
/// of the accounts module.
void registerGoalsModule(GetIt sl) {
  sl
    ..registerLazySingleton<GoalRemoteDataSource>(() => GoalRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<GoalRepository>(() => GoalRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetGoalProgressUseCase(sl()))
    ..registerLazySingleton(() => SaveGoalUseCase(sl()))
    ..registerLazySingleton(() => ArchiveGoalUseCase(sl()))
    ..registerFactory(() => GoalsCubit(sl()))
    ..registerFactory(
      () => GoalFormCubit(getAccounts: sl(), saveGoal: sl(), archiveGoal: sl()),
    );
}
