import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/usecases/save_goal_use_case.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_state.dart';
import 'package:finly/features/goals/presentation/goal_texts.dart';
import 'package:flutter/material.dart';
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

    final cents = centsFromInput(_target.text);
    if (cents <= 0) return;

    context.read<GoalFormCubit>().save(
          SaveGoalParams(
            id: widget.editing?.goal.id,
            workspaceId: widget.workspaceId,
            accountId: account.id,
            currency: account.currency,
            name: _name.text,
            targetCents: cents,
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
        final title = _isEditing ? 'Editar meta' : 'Nova meta';

        if (state.status == GoalFormStatus.loading) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == GoalFormStatus.loadFailed) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Center(
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
            ),
          );
        }

        final options = _options(state.accounts);
        _chosen = _selected(options);
        final saving = state.status == GoalFormStatus.saving;

        return FormPage(
          title: title,
          saveLabel: _isEditing ? 'Salvar alterações' : 'Criar meta',
          saving: saving,
          onSave: () => _submit(options),
          form: _form(context, options, saving),
        );
      },
    );
  }

  Widget _form(BuildContext context, List<AccountEntity> options, bool saving) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final date = _date;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Nome'),
          TextFormField(
            key: const ValueKey('goal-field-Nome da meta'),
            controller: _name,
            enabled: !saving,
            maxLength: SaveGoalUseCase.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: formFieldDecoration(context, hint: 'Ex.: Reserva de emergência'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Informe um nome para a meta.' : null,
          ),
          const SizedBox(height: 12),
          const FieldLabel('Conta que acompanha a meta'),
          if (options.isEmpty)
            Text(
              _isEditing
                  ? 'Nenhuma conta ativa em ${widget.editing!.goal.currency}.'
                  : 'Crie uma conta (que não seja cartão) para acompanhar uma meta.',
              style: text.bodyMedium,
            )
          else
            ChoicePills<String>(
              options: [
                for (final account in options)
                  PillOption(
                    account.id,
                    '${account.name} (${account.currency})',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
              ],
              selected: _accountId,
              onSelected: saving ? null : (id) => setState(() => _accountId = id),
            ),
          const SizedBox(height: 6),
          Text(
            'O progresso é o saldo dessa conta.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          formGap,
          AmountCard(
            fieldKey: const ValueKey('goal-field-Valor da meta'),
            label: 'Valor da meta',
            controller: _target,
            currency: _currency,
            enabled: !saving,
            validator: (value) => centsFromInput(value ?? '') <= 0
                ? 'Informe um valor maior que zero.'
                : null,
          ),
          formGap,
          const FieldLabel('Prazo (opcional)'),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(date == null ? 'Sem prazo' : formatDateBr(date)),
              subtitle: Text(date == null ? 'Toque para escolher uma data' : 'Toque para mudar a data'),
              trailing: date == null
                  ? null
                  : IconButton(
                      tooltip: 'Tirar o prazo',
                      icon: const Icon(Icons.close),
                      onPressed: saving ? null : () => setState(() => _date = null),
                    ),
              onTap: saving ? null : _pickDate,
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: saving ? null : _confirmArchive,
              child: const Text('Arquivar meta'),
            ),
          ],
        ],
      ),
    );
  }
}
