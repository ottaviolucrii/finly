import 'package:finly/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FinlyApp extends StatelessWidget {
  const FinlyApp({
    super.key,
    this.home = const _PlaceholderHome(),
    this.builder,
  });

  /// First screen. main.dart passes the auth gate; tests use the placeholder.
  final Widget home;

  /// Wraps everything the navigator shows. main.dart puts the session lock
  /// here; tests leave it out.
  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: builder,
      home: home,
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Finly', style: text.headlineLarge),
            const SizedBox(height: 8),
            Text('Inteligência Financeira', style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of the app when the build has no Supabase configuration.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Missing configuration.\n\n'
              'Run with:\nflutter run --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}