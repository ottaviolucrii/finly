import 'dart:typed_data';

import 'package:finly/features/receipts/data/receipt_storage.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Takes a photo or picks one from the gallery, already reduced (receipts do
/// not need more than ~1600 px); null when the person gave up.
Future<Uint8List?> pickReceiptPhoto({required bool camera}) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  return file?.readAsBytes();
}

/// The receipt of a transaction: see it, attach one (camera or gallery),
/// replace it or remove it. Pops with true when something changed.
class ReceiptPage extends StatefulWidget {
  final TransactionEntity transaction;
  final ReceiptStorage storage;
  final Future<Uint8List?> Function({required bool camera}) pickPhoto;

  const ReceiptPage({
    super.key,
    required this.transaction,
    required this.storage,
    this.pickPhoto = pickReceiptPhoto,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  late String? _path = widget.transaction.receiptPath;
  String? _link;
  bool _busy = false;
  bool _changed = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _loadLink();
  }

  Future<void> _loadLink() async {
    final path = _path;
    if (path == null || path.isEmpty) return;
    try {
      final link = await widget.storage.link(path);
      if (mounted) setState(() => _link = link);
    } catch (e) {
      if (mounted) setState(() => _problem = 'Não consegui abrir o comprovante agora.');
    }
  }

  /// The transaction with the receipt as it is now (it may have changed here).
  TransactionEntity _current() {
    final t = widget.transaction;
    return TransactionEntity(
      id: t.id,
      workspaceId: t.workspaceId,
      accountId: t.accountId,
      categoryId: t.categoryId,
      type: t.type,
      status: t.status,
      amountCents: t.amountCents,
      currency: t.currency,
      description: t.description,
      occurredAt: t.occurredAt,
      transferId: t.transferId,
      receiptPath: _path,
    );
  }

  Future<void> _attach({required bool camera}) async {
    final photo = await widget.pickPhoto(camera: camera);
    if (photo == null || !mounted) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final path = await widget.storage.attach(_current(), photo);
      if (!mounted) return;
      setState(() {
        _path = path;
        _link = null;
        _changed = true;
      });
      await _loadLink();
    } catch (e) {
      if (mounted) setState(() => _problem = 'Não consegui salvar a foto. Verifique a internet e tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover o comprovante?'),
        content: const Text('A foto é apagada. O lançamento continua.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remover')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.storage.remove(_current());
      if (!mounted) return;
      setState(() {
        _path = null;
        _link = null;
        _changed = true;
      });
    } catch (e) {
      if (mounted) setState(() => _problem = 'Não consegui remover agora. Tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final has = _path != null && _path!.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Comprovante')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(widget.transaction.description, style: text.titleMedium),
            const SizedBox(height: 12),
            if (_busy)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (has)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _link == null
                    ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
                    : InteractiveViewer(
                        maxScale: 4,
                        child: Image.network(
                          _link!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => const SizedBox(
                            height: 200,
                            child: Center(child: Text('Não consegui mostrar a foto.')),
                          ),
                        ),
                      ),
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Guarde a foto do comprovante, da nota ou do recibo junto deste lançamento. '
                      'Só você vê.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_problem!, style: text.bodySmall?.copyWith(color: scheme.error)),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(has ? 'Tirar outra foto' : 'Tirar foto'),
              onPressed: _busy ? null : () => _attach(camera: true),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Escolher da galeria'),
              onPressed: _busy ? null : () => _attach(camera: false),
            ),
            if (has) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover comprovante'),
                onPressed: _busy ? null : _remove,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
