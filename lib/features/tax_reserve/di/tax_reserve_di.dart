import 'package:finly/features/tax_reserve/data/datasources/tax_reserve_remote_data_source.dart';
import 'package:finly/features/tax_reserve/data/repositories/tax_reserve_repository_impl.dart';
import 'package:finly/features/tax_reserve/domain/repositories/tax_reserve_repository.dart';
import 'package:finly/features/tax_reserve/domain/usecases/get_tax_categories_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/get_tax_reserve_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/save_tax_reserve_percent_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/set_category_tax_use_case.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the tax reserve of a company workspace.
void registerTaxReserveModule(GetIt sl) {
  sl
    ..registerLazySingleton<TaxReserveRemoteDataSource>(
      () => TaxReserveRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TaxReserveRepository>(
      () => TaxReserveRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetTaxReserveUseCase(sl()))
    ..registerLazySingleton(() => SaveTaxReservePercentUseCase(sl()))
    ..registerLazySingleton(() => GetTaxCategoriesUseCase(sl()))
    ..registerLazySingleton(() => SetCategoryTaxUseCase(sl()))
    ..registerFactory(
      () => TaxReserveCubit(getTaxReserve: sl(), savePercent: sl()),
    )
    ..registerFactory(
      () => TaxCategoriesCubit(getCategories: sl(), setCategoryTax: sl()),
    );
}
