import 'package:finly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:finly/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/dashboard/domain/usecases/get_dashboard_charts_use_case.dart';
import 'package:finly/features/dashboard/domain/usecases/get_dashboard_use_case.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_charts_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the dashboard classes.
void registerDashboardModule(GetIt sl) {
  sl
    ..registerLazySingleton<DashboardRemoteDataSource>(
      () => DashboardRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetDashboardUseCase(sl(), sl(), sl()))
    ..registerLazySingleton(() => GetDashboardChartsUseCase(sl(), sl()))
    ..registerFactory(() => DashboardCubit(sl()))
    ..registerFactory(() => DashboardChartsCubit(sl()));
}