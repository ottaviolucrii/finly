import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/assistant/presentation/amora_shortcuts.dart';
import 'package:finly/features/assistant/presentation/amora_tips.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 11);

  BudgetProgress budget(String name, int limit, int spent) => BudgetProgress(
        budget: BudgetEntity(
          id: 'b-$name',
          workspaceId: 'w1',
          categoryId: 'c-$name',
          effectiveFrom: DateTime(2026, 10),
          limitCents: limit,
          currency: 'BRL',
        ),
        category: CategoryEntity(
          id: 'c-$name',
          workspaceId: 'w1',
          name: name,
          kind: CategoryKind.expense,
          icon: 'shopping_cart',
          colorHex: '#F29D38',
          isDefault: false,
        ),
        spentCents: spent,
      );

  TransactionEntity upcoming(String description, DateTime day, {TransactionType type = TransactionType.expense}) =>
      TransactionEntity(
        id: 't-$description',
        workspaceId: 'w1',
        accountId: 'a1',
        categoryId: null,
        type: type,
        status: TransactionStatus.pending,
        amountCents: 180000,
        currency: 'BRL',
        description: description,
        occurredAt: day,
      );

  group('the tip of the day', () {
    test('a budget over its limit comes first, worried', () {
      final tip = amoraTipFor(
        budgets: [budget('Mercado', 150000, 140000), budget('Lazer', 40000, 41200)],
        upcoming: [upcoming('Aluguel', today.add(const Duration(days: 1)))],
        today: today,
      );

      expect(tip.mood, AmoraMood.worried);
      expect(tip.text, contains('Lazer passou R\$ 12,00 do limite'));
    });

    test('then something to pay in the next days', () {
      final tip = amoraTipFor(
        budgets: [budget('Mercado', 150000, 140000)],
        upcoming: [upcoming('Aluguel', today.add(const Duration(days: 2)))],
        today: today,
      );

      expect(tip.text, 'Em 2 dias: Aluguel, R\$ 1.800,00.');
    });

    test('money coming in is not a reminder to pay', () {
      final tip = amoraTipFor(
        budgets: const [],
        upcoming: [upcoming('Salário', today, type: TransactionType.income)],
        today: today,
      );

      expect(tip, same(amoraIdleTip));
    });

    test('then a budget close to its limit, with what is left per day', () {
      // 21 days left in October counting today: R$ 105 / 21 = R$ 5 a day.
      final tip = amoraTipFor(budgets: [budget('Mercado', 100000, 89500)], upcoming: const [], today: today);

      expect(tip.text, 'Faltam R\$ 105,00 em Mercado: uns R\$ 5,00 por dia até o fim do mês.');
      expect(tip.mood, AmoraMood.happy);
    });

    test('nothing to say: a tip about the app', () {
      final tip = amoraTipFor(budgets: [budget('Mercado', 100000, 10000)], upcoming: const [], today: today);

      expect(tip, same(amoraIdleTip));
    });
  });

  group('finding a place of the app', () {
    final opened = <String>[];
    AmoraShortcut place(String title, List<String> keywords) => AmoraShortcut(
          title: title,
          hint: '',
          icon: Icons.circle,
          keywords: keywords,
          onOpen: () => opened.add(title),
        );
    final all = [
      place('Pagar fatura', ['fatura', 'pagar', 'cartao']),
      place('Metas', ['objetivo', 'guardar']),
      place('Relatório', ['exportar', 'pdf']),
    ];

    test('accents and capitals do not matter', () {
      expect(plainText('Relatório ÇÃO'), 'relatorio cao');
    });

    test('a question finds the place', () {
      expect(searchShortcuts(all, 'como pago a fatura?').first.title, 'Pagar fatura');
      expect(searchShortcuts(all, 'quero exportar em PDF').first.title, 'Relatório');
      expect(searchShortcuts(all, 'guardar dinheiro').first.title, 'Metas');
    });

    test('nothing typed: all of them; nothing found: none', () {
      expect(searchShortcuts(all, '  '), all);
      expect(searchShortcuts(all, 'xyzw'), isEmpty);
    });
  });
}
