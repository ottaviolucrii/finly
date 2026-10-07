import 'dart:async';

import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:finly/features/lock/presentation/lock_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Puts the lock screen in an overlay of its own. The lock sits above the
/// navigator, which is where the text fields get their overlay from, so
/// without this the password field could not work.
class LockScreenHost extends StatelessWidget {
  const LockScreenHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: LockScreen(
                onSignOut: () =>
                    context.read<AuthBloc>().add(const SignOutRequested()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The lock screen: the phone's biometrics or PIN, or the account password.
class LockScreen extends StatefulWidget {
  final VoidCallback onSignOut;

  const LockScreen({super.key, required this.onSignOut});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _password = TextEditingController();
  bool _prompted = false;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _password.dispose();
    super.dispose();
  }

  /// A one-second tick while a block is running, to count down.
  void _syncTicker({required bool blocked}) {
    if (blocked && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!blocked && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Asks for the fingerprint by itself, once, when it is turned on.
  void _maybeAutoPrompt(AppLockState state) {
    if (_prompted || !state.settingsReady || state.working) return;
    _prompted = true;

    if (state.settings.biometricEnabled && state.deviceSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppLockCubit>().unlockWithDevice();
      });
    }
  }

  void _submit(AppLockCubit cubit) {
    final password = _password.text;
    if (password.isEmpty) return;
    _password.clear();
    cubit.unlockWithPassword(password);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<AppLockCubit, AppLockState>(
      builder: (context, state) {
        final cubit = context.read<AppLockCubit>();
        final now = DateTime.now();
        final until = state.blockedUntil;
        final blocked = until != null && now.isBefore(until);
        _syncTicker(blocked: blocked);
        _maybeAutoPrompt(state);

        final error = lockUnlockError(state, now);
        final busy = state.working;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Finly bloqueado',
                    style: text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confirme que é você para continuar.',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (state.deviceSupported) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Usar biometria ou PIN do aparelho'),
                      onPressed: busy ? null : cubit.unlockWithDevice,
                    ),
                    const SizedBox(height: 16),
                    Text('ou', style: text.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _password,
                    enabled: !busy && !blocked,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(cubit),
                    decoration: const InputDecoration(
                      labelText: 'Senha da conta',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error,
                        style: text.bodyMedium?.copyWith(color: scheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (busy || blocked) ? null : () => _submit(cubit),
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar com a senha'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : widget.onSignOut,
                    child: const Text('Sair da conta'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}