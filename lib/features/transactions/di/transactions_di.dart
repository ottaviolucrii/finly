import 'package:finly/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:finly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finly/features/transactions/domain/usecases/confirm_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/update_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_edit_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the transaction classes.
void registerTransactionsModule(GetIt sl) {
  sl
    // data layer
    ..registerLazySingleton<TransactionRemoteDataSource>(
      () => TransactionRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(sl()),
    )
    // use cases
    ..registerLazySingleton(() => GetTransactionsUseCase(sl()))
    ..registerLazySingleton(() => CreateTransactionUseCase(sl()))
    ..registerLazySingleton(() => UpdateTransactionUseCase(sl()))
    ..registerLazySingleton(() => ConfirmTransactionUseCase(sl()))
    ..registerLazySingleton(() => DeleteTransactionUseCase(sl()))
    ..registerLazySingleton(() => RestoreTransactionUseCase(sl()))
    // presentation
    ..registerFactory(
      () => TransactionsCubit(
        getTransactions: sl(),
        getAccounts: sl(),
        getCategories: sl(),
        confirmTransaction: sl(),
        deleteTransaction: sl(),
        restoreTransaction: sl(),
        deleteTransfer: sl(),
      ),
    )
    ..registerFactory(() => TransactionFormCubit(sl()))
    ..registerFactory(() => TransactionEditCubit(sl()));
}