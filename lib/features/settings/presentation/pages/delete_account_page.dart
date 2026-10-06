import 'package:finly/core/di/injection.dart';
import 'package:finly/features/auth/domain/usecases/delete_account_use_case.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/settings/presentation/cubit/delete_account_cubit.dart';
import 'package:finly/features/settings/presentation/cubit/delete_account_state.dart';
import 'package:finly/features/settings/presentation/settings_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Deletes the account and everything in it, for good. Asks for a typed
/// confirmation and the password.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DeleteAccountCubit>(),
      child: const _DeleteAccountView(),
    );
  }
}

class _DeleteAccountView extends StatefulWidget {
  const _DeleteAccountView();

  @override
  State<_DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<_DeleteAccountView> {
  final _formKey = GlobalKey<FormState>();
  final _confirmation = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _confirmation.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<DeleteAccountCubit>().submit(
          password: _password.text,
          confirmation: _confirmation.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return BlocConsumer<DeleteAccountCubit, DeleteAccountState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.status == DeleteAccountStatus.failure && state.failure != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(settingsFailureMessage(state.failure!))),
            );
        }
        if (state.status == DeleteAccountStatus.success) {
          final navigator = Navigator.of(context);
          final bloc = context.read<AuthBloc>();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Conta excluída.')));
          // Close every page, then show the sign-in screen.
          navigator.popUntil((route) => route.isFirst);
          bloc.add(const BackToSignInRequested());
        }
      },
      builder: (context, state) {
        final submitting = state.status == DeleteAccountStatus.submitting;

        return Scaffold(
          appBar: AppBar(title: const Text('Excluir conta')),
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
                        Card(
                          color: scheme.error.withValues(alpha: 0.12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber, color: scheme.error),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Isto não pode ser desfeito',
                                      style: text.titleMedium?.copyWith(
                                        color: scheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Serão apagados para sempre: seus dois '
                                  'workspaces, contas, cartões, transações, '
                                  'transferências, orçamentos, recorrências, '
                                  'categorias e todo o histórico. Nem nós '
                                  'conseguimos recuperar depois.',
                                  style: text.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _confirmation,
                          enabled: !submitting,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Digite EXCLUIR para confirmar',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (value ?? '').trim().toUpperCase() ==
                                      deleteAccountConfirmationWord
                                  ? null
                                  : 'Digite EXCLUIR para confirmar.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !submitting,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Sua senha',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _showPassword ? 'Ocultar' : 'Mostrar',
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                          validator: (value) =>
                              (value ?? '').isEmpty ? 'Informe a senha.' : null,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                          ),
                          onPressed: submitting ? null : _submit,
                          child: submitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onError,
                                  ),
                                )
                              : const Text('Excluir minha conta'),
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