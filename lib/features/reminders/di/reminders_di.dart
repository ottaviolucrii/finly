import 'package:finly/features/reminders/data/datasources/reminders_remote_data_source.dart';
import 'package:finly/features/reminders/data/local_reminder_scheduler.dart';
import 'package:finly/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:finly/features/reminders/domain/reminder_scheduler.dart';
import 'package:finly/features/reminders/domain/repositories/reminders_repository.dart';
import 'package:finly/features/reminders/domain/usecases/get_notification_prefs_use_case.dart';
import 'package:finly/features/reminders/domain/usecases/save_notification_prefs_use_case.dart';
import 'package:finly/features/reminders/domain/usecases/sync_reminders_use_case.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the reminder classes (local notifications for bills and card
/// invoices that are about to be due).
void registerRemindersModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReminderScheduler>(LocalReminderScheduler.new)
    ..registerLazySingleton<RemindersRemoteDataSource>(
      () => RemindersRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<RemindersRepository>(
      () => RemindersRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetNotificationPrefsUseCase(sl()))
    ..registerLazySingleton(() => SaveNotificationPrefsUseCase(sl()))
    ..registerLazySingleton(() => SyncRemindersUseCase(sl(), sl()))
    ..registerFactory(
      () => RemindersCubit(
        getPrefs: sl(),
        savePrefs: sl(),
        syncReminders: sl(),
        scheduler: sl(),
      ),
    );
}
