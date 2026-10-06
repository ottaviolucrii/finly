import 'package:finly/features/cards/data/datasources/card_remote_data_source.dart';
import 'package:finly/features/cards/data/repositories/card_repository_impl.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/cards/domain/usecases/create_card_use_case.dart';
import 'package:finly/features/cards/domain/usecases/create_installments_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_cards_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoice_transactions_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/domain/usecases/pay_invoice_use_case.dart';
import 'package:finly/features/cards/domain/usecases/update_card_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/card_archive_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/cards_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/installment_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the credit card classes (cards, invoices, installments).
void registerCardsModule(GetIt sl) {
  sl
    // data layer and use cases
    ..registerLazySingleton<CardRemoteDataSource>(
      () => CardRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<CardRepository>(() => CardRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetCardsUseCase(sl()))
    ..registerLazySingleton(() => CreateCardUseCase(sl()))
    ..registerLazySingleton(() => UpdateCardUseCase(sl()))
    ..registerLazySingleton(() => GetInvoicesUseCase(sl()))
    ..registerLazySingleton(() => GetInvoiceTransactionsUseCase(sl()))
    ..registerLazySingleton(() => CreateInstallmentsUseCase(sl()))
    ..registerLazySingleton(() => PayInvoiceUseCase(sl()))
    // presentation
    ..registerFactory(() => CardsCubit(sl()))
    ..registerFactory(() => CardFormCubit(sl()))
    ..registerFactory(() => CardEditCubit(sl()))
    ..registerFactory(() => CardArchiveCubit(sl()))
    ..registerFactory(
      () => InvoicesCubit(getInvoices: sl(), getCards: sl()),
    )
    ..registerFactory(
      () => InvoiceDetailCubit(
        getTransactions: sl(),
        getInvoices: sl(),
        getAccounts: sl(),
        payInvoice: sl(),
      ),
    )
    ..registerFactory(
      () => InstallmentFormCubit(getCategories: sl(), createInstallments: sl()),
    );
}