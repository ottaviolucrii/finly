import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/tax_id_formatter.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/workspaces/presentation/cubit/onboarding_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/onboarding_state.dart';
import 'package:finly/features/workspaces/presentation/workspace_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// First-run flow for a signed-in user without a workspace.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OnboardingCubit>(),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == OnboardingStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(workspaceFailureMessage(state.failure!))),
            );
        }
        if (state.status == OnboardingStatus.success) {
          // The server created the workspace; reload the user so the
          // AuthGate moves on to the home screen.
          context.read<AuthBloc>().add(const UserRefreshRequested());
        }
      },
      builder: (context, state) {
        final submitting = state.status == OnboardingStatus.submitting;
        final type = state.type;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Primeiros passos'),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => context
                        .read<AuthBloc>()
                        .add(const SignOutRequested()),
                child: const Text('Sair'),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: type == null
                      ? const _TypeChooser()
                      : _WorkspaceForm(
                          key: ValueKey(type),
                          type: type,
                          submitting: submitting,
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

class _TypeChooser extends StatelessWidget {
  const _TypeChooser();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.read<OnboardingCubit>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Como você quer começar?',
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha o tipo do seu primeiro workspace. '
          'Cada tipo guarda seus dados separados.',
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _TypeCard(
          icon: Icons.person_outline,
          title: 'Pessoal (CPF)',
          description: 'Gastos do dia a dia, orçamento e metas pessoais.',
          onTap: () => cubit.selectType(WorkspaceType.personal),
        ),
        const SizedBox(height: 12),
        _TypeCard(
          icon: Icons.business_center_outlined,
          title: 'Empresa (CNPJ)',
          description: 'Fluxo de caixa, relatórios e reserva de impostos.',
          onTap: () => cubit.selectType(WorkspaceType.business),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(description, style: text.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceForm extends StatefulWidget {
  final WorkspaceType type;
  final bool submitting;

  const _WorkspaceForm({
    super.key,
    required this.type,
    required this.submitting,
  });

  @override
  State<_WorkspaceForm> createState() => _WorkspaceFormState();
}

class _WorkspaceFormState extends State<_WorkspaceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.type == WorkspaceType.personal ? 'Pessoal' : 'Empresa',
  );
  final _taxId = TextEditingController();

  bool get _isCnpj => widget.type == WorkspaceType.business;

  @override
  void dispose() {
    _name.dispose();
    _taxId.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context
        .read<OnboardingCubit>()
        .submit(name: _name.text, taxId: _taxId.text);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isCnpj ? 'Workspace da empresa' : 'Workspace pessoal',
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            enabled: !widget.submitting,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nome do workspace',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final name = (value ?? '').trim();
              if (name.isEmpty || name.length > 80) {
                return 'Informe um nome (até 80 caracteres).';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _taxId,
            enabled: !widget.submitting,
            keyboardType: _isCnpj ? TextInputType.text : TextInputType.number,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [TaxIdInputFormatter(isCnpj: _isCnpj)],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: _isCnpj ? 'CNPJ' : 'CPF',
              hintText: _isCnpj ? '00.000.000/0000-00' : '000.000.000-00',
              helperText: 'Não poderá ser alterado depois.',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final input = value ?? '';
              final valid = _isCnpj
                  ? Validators.isValidCNPJ(input)
                  : Validators.isValidCPF(input);
              if (valid) return null;
              return _isCnpj ? 'CNPJ inválido.' : 'CPF inválido.';
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.submitting ? null : _submit,
            child: widget.submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Criar workspace'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.submitting
                ? null
                : () => context.read<OnboardingCubit>().backToTypes(),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }
}