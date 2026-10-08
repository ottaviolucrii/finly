import 'package:finly/features/audit/data/datasources/audit_remote_data_source.dart';
import 'package:finly/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:finly/features/audit/domain/repositories/audit_repository.dart';
import 'package:finly/features/audit/domain/usecases/get_audit_history_use_case.dart';
import 'package:finly/features/audit/presentation/cubit/audit_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the history of changes (the audit log viewer).
void registerAuditModule(GetIt sl) {
  sl
    ..registerLazySingleton<AuditRemoteDataSource>(
      () => AuditRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AuditRepository>(() => AuditRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetAuditHistoryUseCase(sl()))
    ..registerFactory(() => AuditCubit(sl()));
}
