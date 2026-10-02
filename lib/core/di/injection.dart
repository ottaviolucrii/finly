import 'package:finly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:finly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt sl = GetIt.instance;

/// Registers everything the app needs. Call once, after Supabase.initialize.
void configureDependencies() {
  sl
    ..registerLazySingleton<SupabaseClient>(() => Supabase.instance.client)
    // auth: data layer
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()))
    // auth: use cases
    ..registerLazySingleton(() => SignInUseCase(sl()))
    ..registerLazySingleton(() => SignUpUseCase(sl()))
    ..registerLazySingleton(() => SignOutUseCase(sl()))
    ..registerLazySingleton(() => GetCurrentUserUseCase(sl()))
    // auth: presentation (a new bloc each time it is requested)
    ..registerFactory(
      () => AuthBloc(
        signIn: sl(),
        signUp: sl(),
        signOut: sl(),
        getCurrentUser: sl(),
      ),
    );
}