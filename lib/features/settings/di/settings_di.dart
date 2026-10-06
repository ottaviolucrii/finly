import 'package:finly/features/settings/presentation/cubit/change_password_cubit.dart';
import 'package:finly/features/settings/presentation/cubit/delete_account_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the settings screens' cubits. Their use cases live in the auth
/// module.
void registerSettingsModule(GetIt sl) {
  sl
    ..registerFactory(() => ChangePasswordCubit(sl()))
    ..registerFactory(() => DeleteAccountCubit(sl()));
}