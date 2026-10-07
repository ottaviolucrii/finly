import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wraps the whole app (it goes in `MaterialApp.builder`) and tells the
/// [RemindersCubit] when to refresh the scheduled reminders: when someone signs
/// in, when the active workspace changes, and when the app leaves the screen or
/// comes back. When someone signs out, it removes every reminder.
class RemindersGate extends StatefulWidget {
  final Widget child;

  const RemindersGate({super.key, required this.child});

  @override
  State<RemindersGate> createState() => _RemindersGateState();
}

class _RemindersGateState extends State<RemindersGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<RemindersCubit>();

    switch (state) {
      case AppLifecycleState.resumed:
        cubit.onResumed();
      case AppLifecycleState.paused:
        cubit.onPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.user?.activeWorkspaceId != current.user?.activeWorkspaceId,
      listener: (context, state) {
        final cubit = context.read<RemindersCubit>();

        if (state.status == AuthStatus.unauthenticated) {
          cubit.onSignedOut();
        } else if (state.status == AuthStatus.authenticated) {
          cubit.onWorkspace(state.user?.activeWorkspaceId);
        }
      },
      child: widget.child,
    );
  }
}
