import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_cubit.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_state.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sits above `MaterialApp` and gives [builder] the theme choice of the user.
/// It reads the saved choice when someone signs in and goes back to the phone's
/// theme when they sign out.
class AppearanceGate extends StatelessWidget {
  final Widget Function(BuildContext context, AppearanceMode mode) builder;

  const AppearanceGate({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final cubit = context.read<AppearanceCubit>();

        if (state.status == AuthStatus.authenticated) {
          cubit.load();
        } else if (state.status == AuthStatus.unauthenticated) {
          cubit.reset();
        }
      },
      child: BlocBuilder<AppearanceCubit, AppearanceState>(
        buildWhen: (previous, current) => previous.mode != current.mode,
        builder: (context, state) => builder(context, state.mode),
      ),
    );
  }
}
