import 'dart:async';

import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:finly/features/lock/presentation/cubit/password_check_result.dart';
import 'package:finly/features/lock/presentation/lock_texts.dart';
import 'package:finly/features/workspaces/presentation/workspace_style.dart';
import 'package:flutter/material.dart';

/// The sheet shown before changing workspace. Switching is never a single tap
/// (SRS FR-W04): depending on the protection level it asks for a confirmation,
/// the phone's biometrics or PIN (with the password as a fallback), or the
/// account password. [onConfirm] is called once, only when the protection is
/// satisfied; a wrong password never calls it.
class WorkspaceSwitchSheet extends StatefulWidget {
  final WorkspaceEntity from;
  final WorkspaceEntity to;
  final SwitchProtection level;

  /// The phone has biometrics or a screen lock to ask.
  final bool deviceSupported;
  final VoidCallback onConfirm;

  /// Shows the phone's prompt. True when it was confirmed.
  final Future<bool> Function() onConfirmWithDevice;

  /// Checks the account password.
  final Future<PasswordCheckResult> Function(String password) onCheckPassword;

  const WorkspaceSwitchSheet({
    super.key,
    required this.from,
    required this.to,
    required this.level,
    required this.deviceSupported,
    required this.onConfirm,
    required this.onConfirmWithDevice,
    required this.onCheckPassword,
  });

  @override
  State<WorkspaceSwitchSheet> createState() => _WorkspaceSwitchSheetState();
}

class _WorkspaceSwitchSheetState extends State<WorkspaceSwitchSheet> {
  final _password = TextEditingController();
  bool _usePassword = false;
  bool _busy = false;
  bool _deviceFailed = false;
  PasswordCheckResult? _failed;
  Timer? _ticker;

  /// The password is asked for at the "password" level, and at the "biometric"
  /// level when the phone cannot do it or the user chose the alternative.
  bool get _passwordMode =>
      widget.level == SwitchProtection.password ||
      (widget.level == SwitchProtection.biometric &&
          (!widget.deviceSupported || _usePassword));

  bool get _deviceMode => widget.level == SwitchProtection.biometric && !_passwordMode;

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

  Future<void> _confirmWithDevice() async {
    setState(() {
      _busy = true;
      _deviceFailed = false;
    });

    final ok = await widget.onConfirmWithDevice();
    if (!mounted) return;

    if (ok) {
      widget.onConfirm();
      return;
    }
    setState(() {
      _busy = false;
      _deviceFailed = true;
    });
  }

  Future<void> _checkPassword() async {
    final password = _password.text;
    if (password.isEmpty || _busy) return;

    setState(() => _busy = true);
    final result = await widget.onCheckPassword(password);
    if (!mounted) return;

    _password.clear();
    if (result.ok) {
      widget.onConfirm();
      return;
    }
    setState(() {
      _busy = false;
      _failed = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final failed = _failed;
    final until = failed?.blockedUntil;
    final blocked = until != null && now.isBefore(until);
    _syncTicker(blocked: blocked);

    final passwordError = failed == null
        ? null
        : lockUnlockError(
            AppLockState(
              error: failed.error,
              attemptsLeft: failed.attemptsLeft,
              blockedUntil: failed.blockedUntil,
            ),
            now,
          );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trocar de workspace',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _WorkspaceRow(label: 'Você está em', workspace: widget.from),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.arrow_downward),
            ),
            _WorkspaceRow(label: 'Mudar para', workspace: widget.to),
            const SizedBox(height: 24),
            if (widget.level == SwitchProtection.confirm)
              FilledButton(
                onPressed: widget.onConfirm,
                child: Text('Mudar para ${widget.to.name}'),
              ),
            if (_deviceMode) ...[
              FilledButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Confirmar com biometria ou PIN'),
                onPressed: _busy ? null : _confirmWithDevice,
              ),
              if (_deviceFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Não foi possível confirmar. Tente de novo ou use a senha.',
                    style: text.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _usePassword = true),
                child: const Text('Usar a senha da conta'),
              ),
            ],
            if (_passwordMode) ...[
              TextField(
                controller: _password,
                enabled: !_busy && !blocked,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _checkPassword(),
                decoration: const InputDecoration(
                  labelText: 'Senha da conta',
                  border: OutlineInputBorder(),
                ),
              ),
              if (passwordError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    passwordError,
                    style: text.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (_busy || blocked) ? null : _checkPassword,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Mudar para ${widget.to.name}'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  final String label;
  final WorkspaceEntity workspace;

  const _WorkspaceRow({required this.label, required this.workspace});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: workspaceAccent(workspace.type),
          foregroundColor: AppColors.white,
          child: Icon(workspaceIcon(workspace.type)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodySmall),
              Text(
                workspace.name,
                style: text.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              Text(workspaceTypeLabel(workspace.type), style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
