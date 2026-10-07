import 'package:finly/features/accounts/di/accounts_di.dart';
import 'package:finly/features/auth/di/auth_di.dart';
import 'package:finly/features/budgets/di/budgets_di.dart';
import 'package:finly/features/cards/di/cards_di.dart';
import 'package:finly/features/categories/di/categories_di.dart';
import 'package:finly/features/dashboard/di/dashboard_di.dart';
import 'package:finly/features/forecast/di/forecast_di.dart';
import 'package:finly/features/lock/di/lock_di.dart';
import 'package:finly/features/recurring/di/recurring_di.dart';
import 'package:finly/features/reminders/di/reminders_di.dart';
import 'package:finly/features/alerts/di/alerts_di.dart';
import 'package:finly/features/trash/di/trash_di.dart';
import 'package:finly/features/reports/di/reports_di.dart';
import 'package:finly/features/settings/di/settings_di.dart';
import 'package:finly/features/transactions/di/transactions_di.dart';
import 'package:finly/features/transfers/di/transfers_di.dart';
import 'package:finly/features/workspaces/di/workspaces_di.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt sl = GetIt.instance;

/// Registers everything the app needs. Call once, after Supabase.initialize.
void configureDependencies() {
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  registerFeatureModules(sl);
}

/// Registers the classes of every feature. It is separate from
/// [configureDependencies] so that a test can run it with a fake Supabase
/// client. Each feature keeps its own wiring in `features/<name>/di/`.
void registerFeatureModules(GetIt sl) {
  registerReportsModule(sl);
  registerAlertsModule(sl);
  registerAuthModule(sl);
  registerWorkspacesModule(sl);
  registerAccountsModule(sl);
  registerCategoriesModule(sl);
  registerLockModule(sl);
  registerTransactionsModule(sl);
  registerTrashModule(sl);
  registerTransfersModule(sl);
  registerCardsModule(sl);
  registerBudgetsModule(sl);
  registerRecurringModule(sl);
  registerRemindersModule(sl);
  registerDashboardModule(sl);
  registerForecastModule(sl);
  registerSettingsModule(sl);
}