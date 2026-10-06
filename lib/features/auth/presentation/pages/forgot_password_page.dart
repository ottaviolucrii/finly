import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/presentation/auth_messages.dart';
import 'package:finly/features/auth/presentation/cubit/password_recovery_cubit.dart';
import 'package:finly/features/auth/presentation/cubit/password_recovery_state.dart';
import 'package:finly/features/auth/presentation/pages/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Step 1 of "Esqueci minha senha": asks for the e-mail and sends a code.
class ForgotPasswordPage extends StatelessWidget {
  /// What was already typed on the sign-in screen.
  final String initialEmail;

  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PasswordRecoveryCubit>(),
      child: _ForgotPasswordView(initialEmail: initialEmail),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordView({required this.initialEmail});

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail.trim());

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<PasswordRecoveryCubit>().requestCode(_email.text);
  }

  void _goToCodeStep() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResetPasswordPage(email: _email.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<PasswordRecoveryCubit, PasswordRecoveryState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == PasswordRecoveryStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(authFailureMessage(state.failure!))),
            );
        }
        if (state.status == PasswordRecoveryStatus.codeSent) _goToCodeStep();
      },
      builder: (context, state) {
        final sending = state.status == PasswordRecoveryStatus.sendingCode;

        return Scaffold(
          appBar: AppBar(title: const Text('Esqueci minha senha')),
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
                          'Informe o e-mail da sua conta. Enviaremos um código '
                          'para você criar uma nova senha.',
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          enabled: !sending,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => sending ? null : _submit(),
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              Validators.isValidEmail((value ?? '').trim())
                                  ? null
                                  : 'Informe um e-mail válido.',
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: sending ? null : _submit,
                          child: sending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Enviar código'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: sending
                              ? null
                              : () {
                                  if (!_formKey.currentState!.validate()) return;
                                  _goToCodeStep();
                                },
                          child: const Text('Já tenho um código'),
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