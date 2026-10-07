import 'package:finly/app.dart';
import 'package:finly/core/config/app_config.dart';
import 'package:finly/core/di/injection.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/pages/auth_gate.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:finly/features/lock/presentation/widgets/app_lock_gate.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:finly/features/reminders/presentation/widgets/reminders_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const ConfigErrorApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  configureDependencies();

  if (kDebugMode) await _checkConnection();

  // The blocs sit above MaterialApp so every pushed page can reach them.
  // AuthStarted restores the stored session before the first real screen.
  // The session lock wraps everything the navigator shows, and the reminders
  // gate (inside it) keeps the scheduled notifications in step with the data.
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AuthBloc>()..add(const AuthStarted())),
        BlocProvider(create: (_) => sl<AppLockCubit>()),
        BlocProvider(create: (_) => sl<RemindersCubit>()),
      ],
      child: FinlyApp(
        home: const AuthGate(),
        builder: (context, child) => AppLockGate(
          child: RemindersGate(child: child ?? const SizedBox.shrink()),
        ),
      ),
    ),
  );
}

/// Debug-only: proves the URL, the key and anonymous RLS work.
Future<void> _checkConnection() async {
  try {
    final rows = await Supabase.instance.client.from('app_config').select();
    debugPrint('Supabase OK: ${rows.length} app_config row(s)');
  } catch (e) {
    debugPrint('Supabase connection problem: $e');
  }
}
