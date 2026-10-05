import 'package:finly/app.dart';
import 'package:finly/core/config/app_config.dart';
import 'package:finly/core/di/injection.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/pages/auth_gate.dart';
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

  // The bloc sits above MaterialApp so every pushed page can reach it.
  // AuthStarted restores the stored session before the first real screen.
  runApp(
    BlocProvider(
      create: (_) => sl<AuthBloc>()..add(const AuthStarted()),
      child: const FinlyApp(home: AuthGate()),
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