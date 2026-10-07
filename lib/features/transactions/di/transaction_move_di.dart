import 'package:finly/features/transactions/data/datasources/transaction_move_remote_data_source.dart';
import 'package:finly/features/transactions/data/repositories/transaction_move_repository_impl.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_move_repository.dart';
import 'package:finly/features/transactions/domain/usecases/move_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_move_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the classes that move a transaction to another account. Reading
/// the accounts uses the use case of the accounts module.
void registerTransactionMoveModule(GetIt sl) {
  sl
    ..registerLazySingleton<TransactionMoveRemoteDataSource>(
      () => TransactionMoveRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TransactionMoveRepository>(
      () => TransactionMoveRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => MoveTransactionUseCase(sl()))
    ..registerFactory(
      () => TransactionMoveCubit(getAccounts: sl(), moveTransaction: sl()),
    );
}
