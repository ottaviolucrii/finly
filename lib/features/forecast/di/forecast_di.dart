import 'package:finly/features/forecast/data/datasources/forecast_remote_data_source.dart';
import 'package:finly/features/forecast/data/repositories/forecast_repository_impl.dart';
import 'package:finly/features/forecast/domain/repositories/forecast_repository.dart';
import 'package:finly/features/forecast/domain/usecases/get_forecast_use_case.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the balance forecast classes.
void registerForecastModule(GetIt sl) {
  sl
    ..registerLazySingleton<ForecastRemoteDataSource>(
      () => ForecastRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<ForecastRepository>(() => ForecastRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetForecastUseCase(sl()))
    ..registerFactory(() => ForecastCubit(sl()));
}
