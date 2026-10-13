import 'package:file_picker/file_picker.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/import/data/import_source.dart';
import 'package:finly/features/import/domain/statement_line.dart';
import 'package:finly/features/import/domain/statement_reading.dart';
import 'package:flutter/material.dart';

/// A file chosen by the person: its name and bytes.
typedef PickedFile = ({String name, List<int> bytes});

/// Opens the phone's file picker for a statement. Any file can be chosen: on
/// Android an .ofx has no known type and a filter would grey it out; whether
/// it is an OFX or a CSV is decided by its content.
Future<PickedFile?> pickStatementFile() async {
  final file = await FilePicker.pickFile(dialogTitle: 'Escolha o extrato (OFX ou CSV)');
  if (file == null) return null;
  final List<int> bytes = await file.readAsBytes();
  return (name: file.name, bytes: bytes);
}

/// Imports a bank statement (OFX or CSV) into [account]: picks the file,
/// shows every line with the suggested category and what is already in Finly,
/// and saves the chosen ones all at once. Pops with the result when saved.
class ImportStatementPage extends StatefulWidget {
  final AccountEntity account;
  final ImportSource source;
  final Future<PickedFile?> Function() pickFile;

  const ImportStatementPage({
    super.key,
    required this.account,
    required this.source,
    this.pickFile = pickStatementFile,
  });

  @override
  State<ImportStatementPage> createState() => _ImportStatementPageState();
}

enum _Stage { picking, reading, preview, saving, failed }

class _ImportStatementPageState extends State<ImportStatementPage> {
  _Stage _stage = _Stage.picking;
  String? _problem;
  String _fileName = '';

  StatementFile? _file;
  bool _invert = false;
  List<StatementLine> _lines = const [];
  List<String> _statuses = const [];
  List<bool> _include = const [];
  List<String?> _categoryIds = const [];
  List<CategoryEntity> _categories = const [];

  bool get _isCard => widget.account.type == AccountType.creditCard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    setState(() {
      _stage = _Stage.picking;
      _problem = null;
    });
    final picked = await widget.pickFile();
    if (!mounted) return;
    if (picked == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _stage = _Stage.reading;
      _fileName = picked.name;
    });
    final file = readStatement(decodeStatement(picked.bytes));
    if (file.lines.isEmpty) {
      setState(() {
        _stage = _Stage.failed;
        _problem = 'Não encontrei lançamentos neste arquivo. Use um extrato OFX, ou um CSV com colunas de data, '
            'descrição e valor.';
      });
      return;
    }
    _file = file;
    // A CSV of a card usually lists purchases as positive numbers.
    final positives = file.lines.where((l) => l.amountCents > 0).length;
    _invert = _isCard && !file.looksLikeCard && positives > file.lines.length / 2;
    await _prepare();
  }

  /// Asks the database what is new, and the usual categories.
  Future<void> _prepare() async {
    final file = _file!;
    final lines = _invert ? [for (final l in file.lines) l.withSignInverted()] : file.lines;
    setState(() => _stage = _Stage.reading);
    try {
      _categories = _categories.isEmpty ? await widget.source.categories(widget.account.workspaceId) : _categories;
      final check = await widget.source.run(widget.account.id, lines, List.filled(lines.length, null), save: false);
      final out = {for (final l in lines) if (l.amountCents < 0) l.description}.toList();
      final inc = {for (final l in lines) if (l.amountCents > 0) l.description}.toList();
      final expenseSuggestions = await widget.source.suggestions(widget.account.workspaceId, out, income: false);
      final incomeSuggestions = await widget.source.suggestions(widget.account.workspaceId, inc, income: true);
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _statuses = check.statuses;
        _include = [for (final s in check.statuses) s == 'new'];
        _categoryIds = [
          for (final l in lines) (l.amountCents < 0 ? expenseSuggestions : incomeSuggestions)[l.description],
        ];
        _stage = _Stage.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _problem = 'Não consegui conferir o extrato agora. Verifique a internet e tente de novo.';
      });
    }
  }

  Future<void> _save() async {
    final chosen = [for (var i = 0; i < _lines.length; i++) if (_include[i]) i];
    if (chosen.isEmpty) return;
    setState(() => _stage = _Stage.saving);
    try {
      final result = await widget.source.run(
        widget.account.id,
        [for (final i in chosen) _lines[i]],
        [for (final i in chosen) _categoryIds[i]],
        save: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = _Stage.preview);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Não consegui importar agora. Nada foi salvo. Tente de novo.')));
    }
  }

  Future<void> _chooseCategory(int index) async {
    final income = _lines[index].amountCents > 0;
    final kind = income ? CategoryKind.income : CategoryKind.expense;
    final options = [for (final c in _categories) if (c.kind == kind) c];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Sem categoria'),
              onTap: () => Navigator.of(sheetContext).pop(''),
            ),
            for (final c in options)
              ListTile(
                leading: Icon(categoryIcon(c.icon), color: categoryColor(c.colorHex)),
                title: Text(c.name),
                selected: c.id == _categoryIds[index],
                onTap: () => Navigator.of(sheetContext).pop(c.id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      final updated = [..._categoryIds];
      updated[index] = chosen.isEmpty ? null : chosen;
      _categoryIds = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget centered(Widget child) => Center(child: Padding(padding: const EdgeInsets.all(24), child: child));

    final Widget body;
    switch (_stage) {
      case _Stage.picking:
      case _Stage.reading:
        body = centered(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_stage == _Stage.picking ? 'Escolha o arquivo do extrato…' : 'Lendo $_fileName…'),
          ],
        ));
      case _Stage.failed:
        body = centered(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(_problem ?? '', textAlign: TextAlign.center, style: text.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: _pick, child: const Text('Escolher outro arquivo')),
          ],
        ));
      case _Stage.preview:
      case _Stage.saving:
        body = _preview(context);
    }

    final chosen = _include.where((x) => x).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar extrato')),
      body: body,
      bottomNavigationBar: (_stage == _Stage.preview || _stage == _Stage.saving)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: (_stage == _Stage.saving || chosen == 0) ? null : _save,
                  child: _stage == _Stage.saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(chosen == 1 ? 'Importar 1 lançamento' : 'Importar $chosen lançamentos'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _preview(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final duplicates = _statuses.where((s) => s == 'duplicate').length;
    final fresh = _statuses.where((s) => s == 'new').length;
    final skipped = _file?.skipped ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_lines.length} lançamentos em $_fileName', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$fresh novos · $duplicates já estão no Finly'
                  '${skipped > 0 ? ' · $skipped linhas não puderam ser lidas' : ''}',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confira as categorias e desmarque o que não quiser. Nada é salvo até você tocar em Importar.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (_isCard && !(_file?.looksLikeCard ?? false))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Valores positivos são compras'),
                    subtitle: const Text('Ligue se o arquivo do cartão mostra as compras sem o sinal de menos.'),
                    value: _invert,
                    onChanged: _stage == _Stage.saving
                        ? null
                        : (value) {
                            _invert = value;
                            _prepare();
                          },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _lines.length; i++) _row(context, i),
      ],
    );
  }

  Widget _row(BuildContext context, int i) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final line = _lines[i];
    final status = i < _statuses.length ? _statuses[i] : 'new';
    final duplicate = status == 'duplicate';
    final paid = status == 'paid_invoice';
    final category = _categories.where((c) => c.id == _categoryIds[i]).firstOrNull;
    final money = Money(line.amountCents.abs(), widget.account.currency).format();

    return Opacity(
      opacity: duplicate ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
          child: Row(
            children: [
              Checkbox(
                value: _include[i],
                onChanged: (duplicate || _stage == _Stage.saving)
                    ? null
                    : (value) => setState(() {
                          final updated = [..._include];
                          updated[i] = value ?? false;
                          _include = updated;
                        }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      duplicate ? '${formatDateBr(line.date)} · Já no Finly' : formatDateBr(line.date),
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (paid)
                      Text('Cai numa fatura já paga: não será importado',
                          style: text.bodySmall?.copyWith(color: scheme.error)),
                    if (!duplicate)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(category == null ? Icons.sell_outlined : categoryIcon(category.icon), size: 16),
                          label: Text(category?.name ?? 'Escolher categoria'),
                          onPressed: _stage == _Stage.saving ? null : () => _chooseCategory(i),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                line.amountCents < 0 ? '- $money' : '+ $money',
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: line.amountCents < 0 ? null : const Color(0xFF0B6B3A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
