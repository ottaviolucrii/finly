import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/usecases/save_goal_use_case.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_state.dart';
import 'package:finly/features/goals/presentation/goal_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates a goal, or changes [editing]. Pops with `true` when the goal was
/// saved or archived. The cubit is created for [workspace].
class GoalFormPage extends StatelessWidget {
  final WorkspaceEntity workspace;
  final GoalProgress? editing;

  const GoalFormPage({super.key, required this.workspace, this.editing});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GoalFormCubit>()..load(workspace.id),
      child: GoalFormView(workspaceId: workspace.id, editing: editing),
    );
  }
}

/// The form itself: it uses the [GoalFormCubit] above it.
class GoalFormView extends StatefulWidget {
  final String workspaceId;
  final GoalProgress? editing;

  const GoalFormView({super.key, required this.workspaceId, this.editing});

  @override
  State<GoalFormView> createState() => _GoalFormViewState();
}

class _GoalFormViewState extends State<GoalFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.editing?.goal.name ?? '');
  late final TextEditingController _target = TextEditingController(
    text: widget.editing == null
        ? ''
        : Money(widget.editing!.goal.targetCents, widget.editing!.goal.currency)
            .format(withSymbol: false),
  );
  late String? _accountId = widget.editing?.goal.accountId;
  late DateTime? _date = widget.editing?.goal.targetDate;
  AccountEntity? _chosen;

  bool get _isEditing => widget.editing != null;

  /// A goal keeps its currency, so when it is changed only the accounts in that
  /// currency can be chosen.
  List<AccountEntity> _options(List<AccountEntity> accounts) {
    final editing = widget.editing;
    if (editing == null) return accounts;
    return [
      for (final account in accounts)
        if (account.currency == editing.goal.currency) account,
    ];
  }

  AccountEntity? _selected(List<AccountEntity> options) {
    for (final account in options) {
      if (account.id == _accountId) return account;
    }
    return null;
  }

  String get _currency => _chosen?.currency ?? widget.editing?.goal.currency ?? 'BRL';

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year, now.month + 3, now.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit(List<AccountEntity> options) {
    final account = _selected(options);
    if (account == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Escolha uma conta.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final target = Money.tryParse(_target.text, account.currency);
    if (target == null || target.cents <= 0) return;

    context.read<GoalFormCubit>().save(
          SaveGoalParams(
            id: widget.editing?.goal.id,
            workspaceId: widget.workspaceId,
            accountId: account.id,
            currency: account.currency,
            name: _name.text,
            targetCents: target.cents,
            targetDate: _date,
          ),
        );
  }

  Future<void> _confirmArchive() async {
    final cubit = context.read<GoalFormCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar meta?'),
        content: const Text(
          'A meta sai da lista. O dinheiro da conta não muda, e o histórico guarda o que foi feito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.archive(widget.editing!.goal.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<GoalFormCubit, GoalFormState>(
      listenWhen: (previous, current) =>
          previous.status != current.status || previous.saveFailure != current.saveFailure,
      listener: (context, state) {
        if (state.status == GoalFormStatus.saved || state.status == GoalFormStatus.archived) {
          Navigator.of(context).pop(true);
        }
        final failure = state.saveFailure;
        if (failure != null && state.status == GoalFormStatus.ready) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(goalFailureMessage(failure))));
        }
      },
      builder: (context, state) {
        final options = _options(state.accounts);
        _chosen = _selected(options);
        final saving = state.status == GoalFormStatus.saving;

        return Scaffold(
          appBar: AppBar(title: Text(_isEditing ? 'Editar meta' : 'Nova meta')),
          body: _body(context, state, options, saving, text),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    GoalFormState state,
    List<AccountEntity> options,
    bool saving,
    TextTheme text,
  ) {
    if (state.status == GoalFormStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == GoalFormStatus.loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(goalFailureMessage(state.loadFailure!), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<GoalFormCubit>().load(widget.workspaceId),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }

    final chosen = _chosen;

    return SafeArea(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !saving,
                    maxLength: SaveGoalUseCase.maxNameLength,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nome da meta',
                      hintText: 'Ex.: Reserva de emergência',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Informe um nome para a meta.' : null,
                  ),
                  const SizedBox(height: 12),
                  Text('Conta que acompanha a meta', style: text.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    'O progresso é o saldo dessa conta.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (options.isEmpty)
                    Text(
                      _isEditing
                          ? 'Nenhuma conta ativa em ${widget.editing!.goal.currency}.'
                          : 'Crie uma conta (que não seja cartão) para acompanhar uma meta.',
                      style: text.bodyMedium,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final account in options)
                          ChoiceChip(
                            avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                            label: Text('${account.name} (${account.currency})'),
                            selected: account.id == _accountId,
                            onSelected: saving
                                ? null
                                : (_) => setState(() => _accountId = account.id),
                          ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _target,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Valor da meta',
                      prefixText: '${Money.symbolFor(chosen?.currency ?? _currency)} ',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = Money.tryParse(value ?? '', _currency);
                      return (amount == null || amount.cents <= 0)
                          ? 'Informe um valor maior que zero (ex.: 5000,00).'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Prazo (opcional)'),
                    subtitle: Text(_date == null ? 'Sem prazo' : formatDateBr(_date!)),
                    trailing: _date == null
                        ? null
                        : IconButton(
                            tooltip: 'Tirar o prazo',
                            icon: const Icon(Icons.close),
                            onPressed: saving ? null : () => setState(() => _date = null),
                          ),
                    onTap: saving ? null : _pickDate,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving ? null : () => _submit(options),
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Salvar alterações' : 'Criar meta'),
                  ),
                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: saving ? null : _confirmArchive,
                        child: const Text('Arquivar meta'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
