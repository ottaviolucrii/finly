import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/presentation/account_style.dart';
import 'package:finly/features/ai/domain/entities/ai_draft.dart';
import 'package:finly/features/ai/domain/repositories/ai_repository.dart';
import 'package:finly/features/ai/presentation/ai_messages.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/presentation/account_choice.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_state.dart';
import 'package:finly/features/transactions/presentation/new_transaction_rules.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How the sheet closed.
enum NewTransactionResult {
  /// A transaction was saved.
  created,

  /// The person chose "Transferência": the caller opens the transfer form.
  transfer,
}

/// Opens the sheet to add an expense or an income. [accounts] must not be
/// empty. Returns null when it was closed without saving.
Future<NewTransactionResult?> showNewTransactionSheet(
  BuildContext context, {
  required String workspaceId,
  required List<AccountEntity> accounts,
  required List<CategoryEntity> categories,
}) {
  return showModalBottomSheet<NewTransactionResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) => sl<TransactionFormCubit>(),
      child: NewTransactionForm(
        workspaceId: workspaceId,
        accounts: accounts,
        categories: categories,
        ai: sl.isRegistered<AiRepository>() ? sl<AiRepository>() : null,
      ),
    ),
  );
}

/// The content of the sheet: the kind (expense, income, transfer), a big
/// amount, a description, the category, the account and the day, and the
/// button to save. It needs a [TransactionFormCubit] above it.
class NewTransactionForm extends StatefulWidget {
  final String workspaceId;
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  /// "Now"; tests pass a fixed date.
  final DateTime Function()? clock;

  /// Reads a sentence into the sheet ("gastei 50 no mercado ontem"); null
  /// hides the field.
  final AiRepository? ai;

  const NewTransactionForm({
    super.key,
    required this.workspaceId,
    required this.accounts,
    required this.categories,
    this.clock,
    this.ai,
  });

  @override
  State<NewTransactionForm> createState() => _NewTransactionFormState();
}

class _NewTransactionFormState extends State<NewTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();

  TransactionType _type = TransactionType.expense;
  late String _accountId = widget.accounts.first.id;
  String? _categoryId;
  QuickDay _quickDay = QuickDay.today;
  late DateTime _picked = _now;
  bool _pending = false;

  /// Why the last save failed, shown above the button (a message at the
  /// bottom of the screen would be hidden behind the sheet).
  String? _error;

  /// The sentence for the AI, while it is being read, and what to say after.
  final _sentence = TextEditingController();
  bool _reading = false;
  String? _aiNote;
  bool _aiNoteIsError = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  AccountEntity get _account => widget.accounts.firstWhere((account) => account.id == _accountId);

  /// The accounts the current kind can use (no cards for money coming in).
  List<AccountEntity> get _accountOptions => accountsForType(_type, widget.accounts);

  /// Keeps the chosen account valid after the kind changed.
  void _fitAccount() {
    final options = _accountOptions;
    if (options.isNotEmpty && !options.any((account) => account.id == _accountId)) {
      _accountId = options.first.id;
    }
  }

  CategoryEntity? get _category {
    for (final category in widget.categories) {
      if (category.id == _categoryId) return category;
    }
    return null;
  }

  List<CategoryEntity> get _categoryOptions {
    final kind = _type == TransactionType.income ? CategoryKind.income : CategoryKind.expense;
    return widget.categories.where((c) => c.kind == kind && !c.isArchived).toList();
  }

  /// Sends the sentence to the AI and fills in the sheet with what it read.
  /// Nothing is saved: the person checks and taps Salvar.
  Future<void> _readSentence() async {
    final ai = widget.ai;
    final text = _sentence.text.trim();
    if (ai == null || text.isEmpty || _reading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _reading = true;
      _aiNote = null;
    });
    final result = await ai.readSentence(
      text: text,
      today: _now,
      categories: widget.categories,
      accounts: widget.accounts,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _reading = false;
        _aiNote = aiFailureMessage(failure);
        _aiNoteIsError = true;
      }),
      (draft) => setState(() {
        _reading = false;
        _apply(draft);
        _sentence.clear();
        _aiNote = 'Preenchido pela IA. Confira e toque em Salvar.';
        _aiNoteIsError = false;
      }),
    );
  }

  /// Puts [draft] into the fields. What the AI did not find stays as it was.
  void _apply(AiDraft draft) {
    _type = draft.type;
    _fitAccount();
    if (draft.amountCents != null) _amount.text = formatCentsInput(draft.amountCents!);
    if (draft.description.isNotEmpty) _description.text = draft.description;
    _categoryId = _categoryOptions.any((c) => c.id == draft.categoryId) ? draft.categoryId : null;
    if (_accountOptions.any((a) => a.id == draft.accountId)) _accountId = draft.accountId!;

    final today = DateTime(_now.year, _now.month, _now.day);
    final day = DateTime(draft.date.year, draft.date.month, draft.date.day);
    if (day == today) {
      _quickDay = QuickDay.today;
    } else if (day == today.subtract(const Duration(days: 1))) {
      _quickDay = QuickDay.yesterday;
    } else {
      _picked = day;
      _quickDay = QuickDay.other;
    }
    _pending = draft.pending || isFutureDay(day, _now);
  }

  @override
  void dispose() {
    _sentence.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _setDay(QuickDay quick) {
    setState(() {
      _quickDay = quick;
      if (isFutureDay(dayFor(quick, _now, _picked), _now)) _pending = true;
    });
  }

  Future<void> _pickDate() async {
    final now = _now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _picked,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _picked = picked);
    _setDay(QuickDay.other);
    if (isFutureDay(picked, now)) setState(() => _pending = true);
  }

  void _submit() {
    if (_error != null) setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final cents = centsFromInput(_amount.text);
    final description = descriptionFor(_description.text, _category);
    if (cents <= 0 || description == null) return;

    final now = _now;
    context.read<TransactionFormCubit>().submit(
          workspaceId: widget.workspaceId,
          accountId: _accountId,
          categoryId: _categoryId,
          type: _type,
          status: _pending ? TransactionStatus.pending : TransactionStatus.posted,
          amountCents: cents,
          currency: _account.currency,
          description: description,
          occurredAt: occurredAtFor(dayFor(_quickDay, now, _picked), now),
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // The keyboard when it is open, otherwise the phone's navigation bar:
    // the button must never sit under either.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final navigationBar = MediaQuery.viewPaddingOf(context).bottom;
    final bottom = keyboard > navigationBar ? keyboard : navigationBar;

    return BlocConsumer<TransactionFormCubit, TransactionFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == TransactionFormStatus.failure && state.failure != null) {
          HapticFeedback.mediumImpact();
          setState(() => _error = transactionFailureMessage(state.failure!));
        }
        if (state.status == TransactionFormStatus.success) {
          Navigator.of(context).pop(NewTransactionResult.created);
        }
      },
      builder: (context, state) {
        final submitting = state.status == TransactionFormStatus.submitting;
        final income = _type == TransactionType.income;
        final options = _categoryOptions;
        final day = dayFor(_quickDay, _now, _picked);

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          container: true,
                          header: true,
                          child: Text('Novo lançamento', style: text.titleLarge?.copyWith(fontSize: 20)),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  if (widget.ai != null) ...[
                    const SizedBox(height: 8),
                    _SentenceField(
                      controller: _sentence,
                      reading: _reading,
                      enabled: !submitting,
                      onRead: _readSentence,
                    ),
                    if (_aiNote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _aiNote!,
                            style: text.bodySmall?.copyWith(
                              color: _aiNoteIsError ? scheme.error : scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  _KindSwitch(
                    income: income,
                    enabled: !submitting,
                    onExpense: () => setState(() {
                      _type = TransactionType.expense;
                      _categoryId = null;
                    }),
                    onIncome: () => setState(() {
                      _type = TransactionType.income;
                      _categoryId = null;
                      _fitAccount();
                    }),
                    onTransfer: () => Navigator.of(context).pop(NewTransactionResult.transfer),
                  ),
                  const SizedBox(height: 20),
                  Text('Valor', textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  TextFormField(
                    controller: _amount,
                    enabled: !submitting,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [CentsInputFormatter()],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 40,
                      letterSpacing: -1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0,00',
                      prefixText: '${Money.symbolFor(_account.currency)} ',
                      prefixStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    validator: (value) => centsFromInput(value ?? '') <= 0 ? 'Informe o valor.' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _description,
                    enabled: !submitting,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: maxDescriptionLength,
                    decoration: InputDecoration(
                      labelText: 'Descrição',
                      hintText: _category == null ? 'Ex.: Mercado, Salário' : 'Se vazio: ${_category!.name}',
                      counterText: '',
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                    ),
                    validator: (value) => descriptionFor(value ?? '', _category) == null
                        ? 'Escreva uma descrição ou escolha uma categoria.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _Label('Categoria'),
                  if (options.isEmpty)
                    Text('Nenhuma categoria disponível.', style: text.bodyMedium)
                  else
                    _ChipRow(
                      children: [
                        for (final category in options)
                          _Choice(
                            label: category.name,
                            icon: categoryIcon(category.icon),
                            selected: _categoryId == category.id,
                            onTap: submitting
                                ? null
                                : () => setState(() => _categoryId = _categoryId == category.id ? null : category.id),
                          ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  _Label(income ? 'Receber em' : 'Pagar com'),
                  if (_accountOptions.isEmpty)
                    Text(noAccountForIncome, style: text.bodyMedium?.copyWith(color: scheme.error)),
                  _ChipRow(
                    children: [
                      for (final account in _accountOptions)
                        _Choice(
                          label: account.name,
                          icon: accountTypeIcon(account.type),
                          selected: _accountId == account.id,
                          onTap: submitting ? null : () => setState(() => _accountId = account.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Label('Data'),
                  _ChipRow(
                    children: [
                      _Choice(
                        label: 'Hoje',
                        selected: _quickDay == QuickDay.today,
                        onTap: submitting ? null : () => _setDay(QuickDay.today),
                      ),
                      _Choice(
                        label: 'Ontem',
                        selected: _quickDay == QuickDay.yesterday,
                        onTap: submitting ? null : () => _setDay(QuickDay.yesterday),
                      ),
                      _Choice(
                        label: _quickDay == QuickDay.other ? formatDateBr(day) : 'Outra data',
                        icon: Icons.calendar_today_outlined,
                        selected: _quickDay == QuickDay.other,
                        onTap: submitting ? null : _pickDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ainda não aconteceu'),
                    subtitle: const Text('Fica pendente: entra no previsto, não no saldo de hoje.'),
                    value: _pending,
                    onChanged: submitting ? null : (value) => setState(() => _pending = value),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    _ErrorBox(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: (submitting || _accountOptions.isEmpty) ? null : _submit,
                    child: submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(income ? 'Salvar receita' : 'Salvar despesa'),
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

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A row of choices that scrolls sideways when it does not fit.
class _ChipRow extends StatelessWidget {
  final List<Widget> children;

  const _ChipRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A pill to tap: blue when chosen.
class _Choice extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const _Choice({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? scheme.primary : scheme.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: selected ? foreground : scheme.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Despesa, Receita and Transferência, like a segmented control.
class _KindSwitch extends StatelessWidget {
  final bool income;
  final bool enabled;
  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onTransfer;

  const _KindSwitch({
    required this.income,
    required this.enabled,
    required this.onExpense,
    required this.onIncome,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? AppColors.canvasDark : AppColors.hairline,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _Segment(label: 'Despesa', selected: !income, onTap: enabled ? onExpense : null)),
          Expanded(child: _Segment(label: 'Receita', selected: income, onTap: enabled ? onIncome : null)),
          Expanded(child: _Segment(label: 'Transferência', selected: false, onTap: enabled ? onTransfer : null)),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? scheme.surface : Colors.transparent,
        elevation: selected ? 1 : 0,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Why saving failed, in red, right above the button. A screen reader reads
/// it as soon as it appears.
class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Escreva como você falaria": a sentence for the AI, with a button to read
/// it. The keyboard's microphone works here too.
class _SentenceField extends StatelessWidget {
  final TextEditingController controller;
  final bool reading;
  final bool enabled;
  final VoidCallback onRead;

  const _SentenceField({
    required this.controller,
    required this.reading,
    required this.enabled,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      enabled: enabled && !reading,
      maxLength: 300,
      minLines: 1,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onRead(),
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Escreva como você falaria: "gastei 50 no mercado ontem"',
        prefixIcon: Icon(Icons.auto_awesome, color: scheme.primary),
        suffixIcon: reading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                tooltip: 'Preencher com a IA',
                icon: const Icon(Icons.arrow_upward),
                onPressed: enabled ? onRead : null,
              ),
        filled: true,
        fillColor: scheme.primary.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}
