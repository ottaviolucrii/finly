import 'package:finly/features/alerts/domain/usecases/get_alerts_use_case.dart';
import 'package:finly/features/alerts/presentation/cubit/alerts_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the alert classes. They read through the budget overview and the
/// dashboard repository, registered by their own modules.
void registerAlertsModule(GetIt sl) {
  sl
    ..registerLazySingleton(() => GetAlertsUseCase(sl(), sl()))
    ..registerFactory(() => AlertsCubit(sl()));
}