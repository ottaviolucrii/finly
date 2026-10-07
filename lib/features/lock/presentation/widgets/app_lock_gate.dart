import 'dart:async';

import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:finly/features/lock/presentation/widgets/lock_screen.dart';
import 'package:finly/features/lock/presentation/widgets/privacy_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wraps the whole app (it goes in `MaterialApp.builder`, above the navigator):
/// it draws the lock screen on top of everything, covers the content when the
/// app leaves the screen, and tells the [AppLockCubit] what happens.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  Timer? _idleTimer;
  bool _covered = false;
  late AuthStatus _previousStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _previousStatus = context.read<AuthBloc>().state.status;
    _idleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) context.read<AppLockCubit>().checkIdle();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<AppLockCubit>();

    switch (state) {
      case AppLifecycleState.resumed:
        cubit.onResumed();
        setState(() => _covered = false);
      case AppLifecycleState.inactive:
        setState(() => _covered = true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        cubit.onBackgrounded();
        setState(() => _covered = true);
      case AppLifecycleState.detached:
        break;
    }
  }

  /// A saved login found at start keeps the lock up. A password typed on the
  /// sign-in screen does not lock the user out of what they just opened.
  void _onAuthChanged(BuildContext context, AuthState state) {
    final cubit = context.read<AppLockCubit>();
    final previous = _previousStatus;
    _previousStatus = state.status;

    switch (state.status) {
      case AuthStatus.loading:
        if (previous != AuthStatus.authenticated && previous != AuthStatus.loading) {
          cubit.unlockForSignIn();
        }
      case AuthStatus.authenticated:
        if (previous == AuthStatus.initial) {
          cubit.onSessionRestored();
        } else if (previous == AuthStatus.loading && !cubit.state.signedIn) {
          cubit.onSignedIn();
        }
      case AuthStatus.unauthenticated:
        cubit.onSignedOut();
      case AuthStatus.initial:
      case AuthStatus.emailVerificationPending:
      case AuthStatus.failure:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onAuthChanged,
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, auth) {
          final signedIn = auth.user != null;

          return BlocBuilder<AppLockCubit, AppLockState>(
            builder: (context, lock) {
              final showLock = signedIn && lock.locked;

              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => context.read<AppLockCubit>().onUserActivity(),
                onPointerMove: (_) => context.read<AppLockCubit>().onUserActivity(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Kept alive but not drawn while locked: nothing to read,
                    // touch or hear with the screen reader.
                    Offstage(offstage: showLock, child: widget.child),
                    if (showLock)
                      const LockScreenHost()
                    else if (_covered && signedIn)
                      const PrivacyCover(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}