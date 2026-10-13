import 'dart:typed_data';

import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/receipts/data/receipt_storage.dart';
import 'package:finly/features/receipts/presentation/receipt_page.dart';
import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStorage implements ReceiptStorage {
  final attached = <String?>[];
  final removed = <String?>[];

  @override
  Future<String> attach(TransactionEntity transaction, Uint8List jpeg) async {
    attached.add(transaction.receiptPath);
    return 'u1/${transaction.id}/1.jpg';
  }

  @override
  Future<String> link(String path) async => 'https://example.invalid/$path';

  @override
  Future<void> remove(TransactionEntity transaction) async => removed.add(transaction.receiptPath);
}

void main() {
  TransactionEntity transaction({String? receipt}) => TransactionEntity(
        id: 't1',
        workspaceId: 'w1',
        accountId: 'a1',
        categoryId: null,
        type: TransactionType.expense,
        status: TransactionStatus.posted,
        amountCents: 4590,
        currency: 'BRL',
        description: 'Almoço com cliente',
        occurredAt: DateTime(2026, 10, 12),
        receiptPath: receipt,
      );

  late FakeStorage storage;
  late List<bool> picks;
  Object? popped;

  setUp(() {
    storage = FakeStorage();
    picks = [];
    popped = null;
  });

  Future<void> open(WidgetTester tester, TransactionEntity item, {bool pickSomething = true}) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ReceiptPage(
                    transaction: item,
                    storage: storage,
                    pickPhoto: ({required bool camera}) async {
                      picks.add(camera);
                      return pickSomething ? Uint8List.fromList([1, 2, 3]) : null;
                    },
                  ),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  test('the model reads the receipt path', () {
    final model = TransactionModel.fromMap({
      'id': 't1',
      'workspace_id': 'w1',
      'account_id': 'a1',
      'category_id': null,
      'type': 'expense',
      'status': 'posted',
      'amount_cents': 4590,
      'currency': 'BRL',
      'description': 'Almoço',
      'occurred_at': '2026-10-12T15:00:00Z',
      'receipt_path': 'u1/t1/1.jpg',
    });

    expect(model.receiptPath, 'u1/t1/1.jpg');
    expect(model.hasReceipt, isTrue);
  });

  testWidgets('without a receipt it explains and offers the camera and the gallery', (tester) async {
    await open(tester, transaction());

    expect(find.textContaining('Só você vê'), findsOneWidget);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);
    expect(find.text('Remover comprovante'), findsNothing);
  });

  testWidgets('a photo is attached, and going back says something changed', (tester) async {
    await open(tester, transaction());

    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(picks, [true]);
    expect(storage.attached, [null]);
    expect(find.text('Remover comprovante'), findsOneWidget);
    expect(find.text('Tirar outra foto'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
  });

  testWidgets('giving up on the photo changes nothing', (tester) async {
    await open(tester, transaction(), pickSomething: false);

    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();

    expect(picks, [false]);
    expect(storage.attached, isEmpty);
  });

  testWidgets('removing asks first, then removes', (tester) async {
    await open(tester, transaction(receipt: 'u1/t1/old.jpg'));

    await tester.tap(find.text('Remover comprovante'));
    await tester.pumpAndSettle();
    expect(find.text('Remover o comprovante?'), findsOneWidget);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(storage.removed, ['u1/t1/old.jpg']);
    expect(find.text('Tirar foto'), findsOneWidget);
  });
}
