import 'package:finly/features/categories/data/datasources/category_remote_data_source.dart';
import 'package:finly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/categories/domain/usecases/create_category_use_case.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:finly/features/categories/domain/usecases/set_category_archived_use_case.dart';
import 'package:finly/features/categories/domain/usecases/update_category_use_case.dart';
import 'package:finly/features/categories/presentation/cubit/categories_cubit.dart';
import 'package:finly/features/categories/presentation/cubit/category_form_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the category classes.
void registerCategoriesModule(GetIt sl) {
  sl
    // data layer
    ..registerLazySingleton<CategoryRemoteDataSource>(
      () => CategoryRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(sl()),
    )
    // use cases
    ..registerLazySingleton(() => GetCategoriesUseCase(sl()))
    ..registerLazySingleton(() => GetAllCategoriesUseCase(sl()))
    ..registerLazySingleton(() => CreateCategoryUseCase(sl()))
    ..registerLazySingleton(() => UpdateCategoryUseCase(sl()))
    ..registerLazySingleton(() => SetCategoryArchivedUseCase(sl()))
    // presentation
    ..registerFactory(
      () => CategoriesCubit(getAll: sl(), setArchived: sl()),
    )
    ..registerFactory(
      () => CategoryFormCubit(create: sl(), update: sl()),
    );
}