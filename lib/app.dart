import 'package:finly/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FinlyApp extends StatelessWidget {
  const FinlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _PlaceholderHome(),
    );
  }
}

/// Temporary screen until the sign-in flow exists (Phase 1).
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