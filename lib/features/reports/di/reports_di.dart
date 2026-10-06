import 'package:finly/features/reports/domain/usecases/get_monthly_report_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the report classes. They read through the dashboard and category
/// repositories, registered by their own modules.
void registerReportsModule(GetIt sl) {
  sl
    ..registerLazySingleton(() => GetMonthlyReportUseCase(sl(), sl()))
    ..registerFactory(() => ReportsCubit(sl()));
}