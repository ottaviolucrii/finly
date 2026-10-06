import 'package:finly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:finly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/change_password_use_case.dart';
import 'package:finly/features/auth/domain/usecases/delete_account_use_case.dart';
import 'package:finly/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:finly/features/auth/domain/usecases/switch_workspace_use_case.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:get_it/get_it.dart';

/// Registers the sign-in, sign-up and session classes.
void registerAuthModule(GetIt sl) {
  sl
    // data layer
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()))
    // use cases
    ..registerLazySingleton(() => SignInUseCase(sl()))
    ..registerLazySingleton(() => SignUpUseCase(sl()))
    ..registerLazySingleton(() => SignOutUseCase(sl()))
    ..registerLazySingleton(() => GetCurrentUserUseCase(sl()))
    ..registerLazySingleton(() => SwitchWorkspaceUseCase(sl()))
    ..registerLazySingleton(() => ChangePasswordUseCase(sl()))
    ..registerLazySingleton(() => DeleteAccountUseCase(sl()))
    // presentation (a new bloc each time it is requested)
    ..registerFactory(
      () => AuthBloc(
        signIn: sl(),
        signUp: sl(),
        signOut: sl(),
        getCurrentUser: sl(),
      ),
    );
}