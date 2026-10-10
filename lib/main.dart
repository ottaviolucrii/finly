import 'dart:io';

import 'package:finly/app.dart';
import 'package:finly/core/config/app_config.dart';
import 'package:finly/core/di/injection.dart';
import 'package:finly/core/offline/cache_store.dart';
import 'package:finly/core/offline/caching_http_client.dart';
import 'package:finly/core/offline/offline_banner.dart';
import 'package:finly/core/offline/offline_probe.dart';
import 'package:finly/core/offline/offline_status.dart';
import 'package:finly/core/offline/remembered_user.dart';
import 'package:finly/core/offline/session_restorer.dart';
import 'package:finly/features/appearance/presentation/appearance_mode_x.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_cubit.dart';
import 'package:finly/features/appearance/presentation/widgets/appearance_gate.dart';
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
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const ConfigErrorApp());
    return;
  }

  // A copy of every read, for when the phone has no internet. It sits under the
  // whole app: each read that works is kept, and when the connection is gone
  // the last copy is shown. No screen needs to know.
  final cacheStore = FileCacheStore(
    directory: () async => Directory('${(await getApplicationSupportDirectory()).path}/offline_cache'),
  );
  final offlineStatus = OfflineStatus();

  // What the phone remembers of the login. The login library drops its session
  // when an expired login cannot be renewed without internet; the text it saved
  // on the phone stays. So the app can still open with the saved data, and it
  // brings the login back when the internet returns.
  final sessionMemory = PreferencesSessionMemory(sessionStorageKeyFor(AppConfig.supabaseUrl));
  RememberedSession.memory = sessionMemory;
  final sessionRestorer = SessionRestorer(
    memory: sessionMemory,
    hasSession: () => Supabase.instance.client.auth.currentSession != null,
    recover: (raw) async {
      await Supabase.instance.client.auth.recoverSession(raw);
    },
  );
  Future<void> restoreSession() async {
    if (await sessionRestorer.restore()) offlineStatus.markOnline();
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    httpClient: CachingHttpClient(
      inner: http.Client(),
      store: cacheStore,
      status: offlineStatus,
      rememberedUserId: () async => (await sessionMemory.user())?.id,
      restoreSession: restoreSession,
    ),
  );
  configureDependencies();
  sl
    ..registerSingleton<CacheStore>(cacheStore)
    ..registerSingleton<OfflineStatus>(offlineStatus);

  // Signing out, or deleting the account, erases the copies kept on the phone.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut) cacheStore.clear();
  });

  // While there is no connection, ask now and then whether it is back.
  OfflineProbe(status: offlineStatus, reachable: () => _serverReachable(restoreSession));

  if (kDebugMode) await _checkConnection();

  // The blocs sit above MaterialApp so every pushed page can reach them.
  // AuthStarted restores the stored session before the first real screen.
  // The appearance gate gives MaterialApp the theme the user chose, the session
  // lock wraps everything the navigator shows, and the reminders gate (inside
  // it) keeps the scheduled notifications in step with the data.
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AuthBloc>()..add(const AuthStarted())),
        BlocProvider(create: (_) => sl<AppearanceCubit>()),
        BlocProvider(create: (_) => sl<AppLockCubit>()),
        BlocProvider(create: (_) => sl<RemindersCubit>()),
      ],
      child: AppearanceGate(
        builder: (context, mode) => ListenableBuilder(
          listenable: offlineStatus,
          // A new key builds the whole app again. It changes only when the
          // person taps "Atualizar" after the internet came back, so every
          // screen reads live data.
          builder: (context, _) => KeyedSubtree(
            key: ValueKey(offlineStatus.refreshEpoch),
            child: FinlyApp(
              themeMode: mode.themeMode,
              home: const AuthGate(),
              builder: (context, child) => AppLockGate(
                child: RemindersGate(
                  child: OfflineBanner(
                    status: offlineStatus,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// True when the server answers at all (any answer counts, even an error).
Future<bool> _serverReachable(Future<void> Function() restoreSession) async {
  final client = http.Client();
  try {
    await client.head(Uri.parse(AppConfig.supabaseUrl)).timeout(const Duration(seconds: 5));
    // The server answers: bring the login back if the library lost it.
    await restoreSession();
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
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
