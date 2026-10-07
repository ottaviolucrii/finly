import 'package:finly/core/security/device_authenticator.dart';
import 'package:finly/features/lock/data/datasources/lock_remote_data_source.dart';
import 'package:finly/features/lock/data/repositories/lock_repository_impl.dart';
import 'package:finly/features/lock/domain/repositories/lock_repository.dart';
import 'package:finly/features/lock/domain/usecases/get_lock_settings_use_case.dart';
import 'package:finly/features/lock/domain/usecases/save_lock_settings_use_case.dart';
import 'package:finly/features/lock/domain/usecases/verify_password_use_case.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the session lock classes.
void registerLockModule(GetIt sl) {
  sl
    ..registerLazySingleton<DeviceAuthenticator>(LocalAuthDeviceAuthenticator.new)
    ..registerLazySingleton<LockRemoteDataSource>(
      () => LockRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<LockRepository>(() => LockRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetLockSettingsUseCase(sl()))
    ..registerLazySingleton(() => SaveLockSettingsUseCase(sl()))
    ..registerLazySingleton(() => VerifyPasswordUseCase(sl()))
    ..registerFactory(
      () => AppLockCubit(
        getSettings: sl(),
        saveSettings: sl(),
        verifyPassword: sl(),
        device: sl(),
      ),
    );
}