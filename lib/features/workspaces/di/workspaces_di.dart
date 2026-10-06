import 'package:finly/features/workspaces/data/datasources/workspace_remote_data_source.dart';
import 'package:finly/features/workspaces/data/repositories/workspace_repository_impl.dart';
import 'package:finly/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:finly/features/workspaces/domain/usecases/create_workspace_use_case.dart';
import 'package:finly/features/workspaces/presentation/cubit/onboarding_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the workspace classes (onboarding and switching).
void registerWorkspacesModule(GetIt sl) {
  sl
    ..registerLazySingleton<WorkspaceRemoteDataSource>(
      () => WorkspaceRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<WorkspaceRepository>(
      () => WorkspaceRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => CreateWorkspaceUseCase(sl()))
    ..registerFactory(() => OnboardingCubit(sl()))
    ..registerFactory(() => SwitchWorkspaceCubit(sl()));
}