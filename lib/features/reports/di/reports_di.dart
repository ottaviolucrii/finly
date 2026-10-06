import 'package:finly/core/share/file_sharer.dart';
import 'package:finly/features/reports/domain/usecases/export_month_use_case.dart';
import 'package:finly/features/reports/domain/usecases/get_monthly_report_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/export_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the report classes. They read through the dashboard, category,
/// account and transaction classes, registered by their own modules.
void registerReportsModule(GetIt sl) {
  sl
    ..registerLazySingleton<FileSharer>(() => const SharePlusFileSharer())
    ..registerLazySingleton(() => GetMonthlyReportUseCase(sl(), sl()))
    ..registerLazySingleton(() => ExportMonthUseCase(sl(), sl(), sl()))
    ..registerFactory(() => ReportsCubit(sl()))
    ..registerFactory(() => ExportCubit(exportMonth: sl(), sharer: sl()));
}