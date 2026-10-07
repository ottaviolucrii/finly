import 'package:finly/features/appearance/data/datasources/appearance_remote_data_source.dart';
import 'package:finly/features/appearance/data/repositories/appearance_repository_impl.dart';
import 'package:finly/features/appearance/domain/repositories/appearance_repository.dart';
import 'package:finly/features/appearance/domain/usecases/get_appearance_use_case.dart';
import 'package:finly/features/appearance/domain/usecases/save_appearance_use_case.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the appearance (light, dark, system) classes.
void registerAppearanceModule(GetIt sl) {
  sl
    ..registerLazySingleton<AppearanceRemoteDataSource>(
      () => AppearanceRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AppearanceRepository>(
      () => AppearanceRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetAppearanceUseCase(sl()))
    ..registerLazySingleton(() => SaveAppearanceUseCase(sl()))
    ..registerFactory(
      () => AppearanceCubit(getAppearance: sl(), saveAppearance: sl()),
    );
}
