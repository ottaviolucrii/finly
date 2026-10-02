import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:finly/features/auth/presentation/pages/home_placeholder_page.dart';
import 'package:finly/features/auth/presentation/pages/sign_in_page.dart';
import 'package:finly/features/auth/presentation/pages/splash_page.dart';
import 'package:finly/features/auth/presentation/pages/verify_email_page.dart';
import 'package:finly/features/workspaces/presentation/pages/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Chooses the first screen from the auth state.
/// Temporary: replaced by router guards (go_router) later.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.initial) return const SplashPage();

        final user = state.user;
        if (user != null) {
          // Signed in but no workspace yet: onboarding.
          return user.workspaces.isEmpty
              ? const OnboardingPage()
              : const HomePlaceholderPage();
        }

        if (state.status == AuthStatus.emailVerificationPending) {
          return VerifyEmailPage(email: state.email ?? '');
        }
        return const SignInPage();
      },
    );
  }
}