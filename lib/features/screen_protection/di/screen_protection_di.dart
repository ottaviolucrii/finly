import 'package:finly/core/security/screen_protection.dart';
import 'package:finly/features/screen_protection/presentation/cubit/screen_protection_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the switch that blocks screenshots.
void registerScreenProtectionModule(GetIt sl) {
  sl
    ..registerLazySingleton<ScreenProtection>(() => PlatformScreenProtection())
    ..registerFactory(() => ScreenProtectionCubit(sl()));
}
