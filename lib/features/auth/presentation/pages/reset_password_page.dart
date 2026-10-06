import 'dart:async';

import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/presentation/auth_messages.dart';
import 'package:finly/features/auth/presentation/cubit/password_recovery_cubit.dart';
import 'package:finly/features/auth/presentation/cubit/password_recovery_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Step 2 of "Esqueci minha senha": the code from the e-mail and the new
/// password. When it works, it goes back to the sign-in screen.
class ResetPasswordPage extends StatelessWidget {
  final String email;

  const ResetPasswordPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PasswordRecoveryCubit>(),
      child: _ResetPasswordView(email: email),
    );
  }
}

class _ResetPasswordView extends StatefulWidget {
  final String email;

  const _ResetPasswordView({required this.email});

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  /// Seconds to wait before a new code can be requested.
  static const _cooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPasswords = false;

  Timer? _timer;
  int _cooldown = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<PasswordRecoveryCubit>().reset(
      email: widget.email,
      code: _code.text,
      newPassword: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<PasswordRecoveryCubit, PasswordRecoveryState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);

        if (state.status == PasswordRecoveryStatus.failure &&
            state.failure != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(authFailureMessage(state.failure!))),
            );
        }
        if (state.status == PasswordRecoveryStatus.codeSent) {
          _startCooldown();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Código enviado.')));
        }
        if (state.status == PasswordRecoveryStatus.resetDone) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Senha alterada. Entre com a nova senha.'),
              ),
            );
          // Back to the sign-in screen, the first one of the stack.
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      builder: (context, state) {
        final busy = state.isBusy;
        final resetting = state.status == PasswordRecoveryStatus.resetting;
        final canResend = !busy && _cooldown <= 0;

        return Scaffold(
          appBar: AppBar(title: const Text('Nova senha')),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Se existe uma conta com ${widget.email}, enviamos um '
                          'código para esse e-mail. Confira também a caixa de '
                          'spam.',
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _code,
                          enabled: !busy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Código do e-mail',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              RegExp(
                                r'^\d{6,10}$',
                              ).hasMatch((value ?? '').trim())
                              ? null
                              : 'Informe o código que veio no e-mail.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !busy,
                          obscureText: !_showPasswords,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nova senha',
                            helperText:
                                'Mínimo de 8 caracteres, com letras e números.',
                            helperMaxLines: 2,
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              Validators.isValidPassword(value ?? '')
                              ? null
                              : 'Use 8 caracteres ou mais, com letras e números.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirm,
                          enabled: !busy,
                          obscureText: !_showPasswords,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar a nova senha',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value != _password.text
                              ? 'As senhas não são iguais.'
                              : null,
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Mostrar as senhas'),
                          value: _showPasswords,
                          onChanged: busy
                              ? null
                              : (value) => setState(
                                  () => _showPasswords = value ?? false,
                                ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: busy ? null : _submit,
                          child: resetting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Alterar senha'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: canResend
                              ? () => context
                                    .read<PasswordRecoveryCubit>()
                                    .requestCode(widget.email)
                              : null,
                          child: Text(
                            _cooldown > 0
                                ? 'Reenviar código em ${_cooldown}s'
                                : 'Reenviar código',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
