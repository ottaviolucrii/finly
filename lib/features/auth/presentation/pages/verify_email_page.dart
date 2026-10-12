import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VerifyEmailPage extends StatelessWidget {
  final String email;

  const VerifyEmailPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Confirme seu e-mail',
      subtitle: 'Falta só um passo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AmoraAvatar(size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Enviamos um link de confirmação para '),
                      TextSpan(text: email, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  style: text.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '1. Abra o e-mail no seu celular.\n2. Toque no link de confirmação.\n3. Volte aqui e entre no app.',
              style: text.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Não chegou? Veja a caixa de spam ou promoções.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.read<AuthBloc>().add(const BackToSignInRequested()),
            child: const Text('Voltar para entrar'),
          ),
        ],
      ),
    );
  }
}
