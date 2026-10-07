import 'package:finly/core/di/injection.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/archived_accounts_cubit.dart';
import 'package:finly/features/alerts/presentation/cubit/alerts_cubit.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_cubit.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/cubit/password_recovery_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_archive_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/cards_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/installment_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:finly/features/categories/presentation/cubit/categories_cubit.dart';
import 'package:finly/features/categories/presentation/cubit/category_form_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_charts_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_cubit.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_delete_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_edit_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_form_cubit.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/export_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/pdf_export_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:finly/features/settings/presentation/cubit/change_password_cubit.dart';
import 'package:finly/features/settings/presentation/cubit/delete_account_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_edit_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_move_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_cubit.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_cubit.dart';
import 'package:finly/features/trash/presentation/cubit/trash_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/onboarding_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Builds every bloc and cubit the app uses, with a fake Supabase client. If a
/// feature forgets to register something, this fails here instead of crashing
/// on a screen.
void main() {
  late GetIt di;

  setUp(() {
    di = GetIt.asNewInstance();
    di.registerLazySingleton<SupabaseClient>(MockSupabaseClient.new);
    registerFeatureModules(di);
  });

  tearDown(() => di.reset());

  test('every bloc and cubit can be built from the wiring', () async {
    final built = <BlocBase<Object?>>[
      di<AuthBloc>(),
      di<PasswordRecoveryCubit>(),
      di<AppLockCubit>(),
      di<SwitchWorkspaceCubit>(),
      di<OnboardingCubit>(),
      di<AccountsCubit>(),
      di<ArchivedAccountsCubit>(),
      di<AccountFormCubit>(),
      di<AccountEditCubit>(),
      di<CategoriesCubit>(),
      di<CategoryFormCubit>(),
      di<TransactionsCubit>(),
      di<TransactionFormCubit>(),
      di<TransactionMoveCubit>(),
      di<TransactionEditCubit>(),
      di<TrashCubit>(),
      di<TransferFormCubit>(),
      di<CardsCubit>(),
      di<CardFormCubit>(),
      di<CardEditCubit>(),
      di<CardArchiveCubit>(),
      di<InvoicesCubit>(),
      di<InvoiceDetailCubit>(),
      di<InstallmentFormCubit>(),
      di<BudgetsCubit>(),
      di<BudgetFormCubit>(),
      di<AlertsCubit>(),
      di<AppearanceCubit>(),
      di<RecurringCubit>(),
      di<RecurringFormCubit>(),
      di<RecurringEditCubit>(),
      di<RecurringDeleteCubit>(),
      di<DashboardCubit>(),
      di<DashboardChartsCubit>(),
      di<ForecastCubit>(),
      di<ReportsCubit>(),
      di<ExportCubit>(),
      di<PdfExportCubit>(),
      di<RemindersCubit>(),
      di<ChangePasswordCubit>(),
      di<DeleteAccountCubit>(),
    ];

    expect(built, hasLength(41));
    for (final bloc in built) {
      await bloc.close();
    }
  });

  test('a cubit asked for twice is a new instance each time', () {
    expect(identical(di<AccountsCubit>(), di<AccountsCubit>()), isFalse);
  });
}