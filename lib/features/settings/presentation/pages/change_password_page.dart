import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/settings/presentation/cubit/change_password_cubit.dart';
import 'package:finly/features/settings/presentation/cubit/change_password_state.dart';
import 'package:finly/features/settings/presentation/settings_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Changes the password. Asks for the current one first. Pops with `true`
/// when it worked.
class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChangePasswordCubit>(),
      child: const _ChangePasswordView(),
    );
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPasswords = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ChangePasswordCubit>().submit(
          currentPassword: _current.text,
          newPassword: _new.text,
        );
  }

  InputDecoration _decoration(String label, {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.status == ChangePasswordStatus.failure && state.failure != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(settingsFailureMessage(state.failure!))),
            );
        }
        if (state.status == ChangePasswordStatus.success) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Senha alterada. Os outros dispositivos foram desconectados.',
                ),
              ),
            );
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == ChangePasswordStatus.submitting;

        return Scaffold(
          appBar: AppBar(title: const Text('Alterar senha')),
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
                          'Por segurança, confirme sua senha atual.',
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _current,
                          enabled: !submitting,
                          obscureText: !_showPasswords,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.next,
                          decoration: _decoration('Senha atual'),
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Informe a senha atual.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _new,
                          enabled: !submitting,
                          obscureText: !_showPasswords,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          decoration: _decoration(
                            'Nova senha',
                            helper: 'Mínimo de 8 caracteres, com letras e números.',
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (!Validators.isValidPassword(password)) {
                              return 'Use 8 caracteres ou mais, com letras e números.';
                            }
                            if (password == _current.text) {
                              return 'A nova senha deve ser diferente da atual.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirm,
                          enabled: !submitting,
                          obscureText: !_showPasswords,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          decoration: _decoration('Confirmar a nova senha'),
                          validator: (value) => value != _new.text
                              ? 'As senhas não são iguais.'
                              : null,
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Mostrar as senhas'),
                          value: _showPasswords,
                          onChanged: submitting
                              ? null
                              : (value) =>
                                  setState(() => _showPasswords = value ?? false),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: submitting ? null : _submit,
                          child: submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Alterar senha'),
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