import 'package:finly/features/transfers/data/datasources/transfer_remote_data_source.dart';
import 'package:finly/features/transfers/data/repositories/transfer_repository_impl.dart';
import 'package:finly/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:finly/features/transfers/domain/usecases/create_transfer_use_case.dart';
import 'package:finly/features/transfers/domain/usecases/delete_transfer_use_case.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the transfer classes.
void registerTransfersModule(GetIt sl) {
  sl
    ..registerLazySingleton<TransferRemoteDataSource>(
      () => TransferRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TransferRepository>(
      () => TransferRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => CreateTransferUseCase(sl()))
    ..registerLazySingleton(() => DeleteTransferUseCase(sl()))
    ..registerFactory(() => TransferFormCubit(sl(), sl()));
}