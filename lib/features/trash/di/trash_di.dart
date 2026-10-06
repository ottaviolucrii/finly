import 'package:finly/features/trash/data/datasources/trash_remote_data_source.dart';
import 'package:finly/features/trash/data/repositories/trash_repository_impl.dart';
import 'package:finly/features/trash/domain/repositories/trash_repository.dart';
import 'package:finly/features/trash/domain/usecases/get_trash_use_case.dart';
import 'package:finly/features/trash/domain/usecases/get_trashed_transfers_use_case.dart';
import 'package:finly/features/trash/domain/usecases/restore_transfer_use_case.dart';
import 'package:finly/features/trash/presentation/cubit/trash_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the trash classes. Restoring a transaction uses the transaction
/// use case, registered by the transactions module.
void registerTrashModule(GetIt sl) {
  sl
    ..registerLazySingleton<TrashRemoteDataSource>(
      () => TrashRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TrashRepository>(() => TrashRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetTrashUseCase(sl()))
    ..registerLazySingleton(() => GetTrashedTransfersUseCase(sl()))
    ..registerLazySingleton(() => RestoreTransferUseCase(sl()))
    ..registerFactory(
      () => TrashCubit(
        getTrash: sl(),
        getTransfers: sl(),
        restoreTransaction: sl(),
        restoreTransfer: sl(),
      ),
    );
}