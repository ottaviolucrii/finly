import 'package:finly/features/data_export/data/datasources/data_export_remote_data_source.dart';
import 'package:finly/features/data_export/data/repositories/data_export_repository_impl.dart';
import 'package:finly/features/data_export/domain/repositories/data_export_repository.dart';
import 'package:finly/features/data_export/domain/usecases/export_my_data_use_case.dart';
import 'package:finly/features/data_export/presentation/cubit/data_export_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the export of all the data of the user. The file is shared with
/// the same `FileSharer` as the report exports.
void registerDataExportModule(GetIt sl) {
  sl
    ..registerLazySingleton<DataExportRemoteDataSource>(
      () => DataExportRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<DataExportRepository>(
      () => DataExportRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => ExportMyDataUseCase(sl()))
    ..registerFactory(
      () => DataExportCubit(exportMyData: sl(), sharer: sl()),
    );
}
