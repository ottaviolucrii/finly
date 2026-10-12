import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/ai/data/ai_remote_data_source.dart';
import 'package:finly/features/ai/data/ai_repository_impl.dart';
import 'package:finly/features/ai/domain/entities/ai_draft.dart';
import 'package:finly/features/ai/presentation/ai_messages.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements AiRemoteDataSource {}

void main() {
  final today = DateTime(2026, 10, 11);

  const card = AccountEntity(
    id: 'a2',
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.creditCard,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: -184335,
    projectedBalanceCents: -184335,
  );
  const market = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Mercado',
    kind: CategoryKind.expense,
    icon: 'shopping_cart',
    colorHex: '#F29D38',
    isDefault: true,
  );
  const old = CategoryEntity(
    id: 'c9',
    workspaceId: 'w1',
    name: 'Antiga',
    kind: CategoryKind.expense,
    icon: 'shopping_cart',
    colorHex: '#F29D38',
    isDefault: false,
    isArchived: true,
  );

  group('AiDraft.fromJson', () {
    test('reads a full answer', () {
      final draft = AiDraft.fromJson({
        'type': 'expense',
        'amountCents': 5000,
        'description': 'Mercado',
        'categoryId': 'c1',
        'accountId': 'a2',
        'date': '2026-10-10',
        'pending': false,
      }, fallbackDate: today);

      expect(draft.type, TransactionType.expense);
      expect(draft.amountCents, 5000);
      expect(draft.categoryId, 'c1');
      expect(draft.date, DateTime(2026, 10, 10));
    });

    test('missing or wrong fields become empty, a bad date becomes today', () {
      final draft = AiDraft.fromJson({'type': 'income', 'amountCents': -3, 'date': 'ontem'}, fallbackDate: today);

      expect(draft.type, TransactionType.income);
      expect(draft.amountCents, isNull);
      expect(draft.description, '');
      expect(draft.categoryId, isNull);
      expect(draft.date, today);
    });
  });

  group('what goes to the AI', () {
    final body = aiRequestBody(text: '  gastei 50  ', today: today, categories: const [market, old], accounts: const [card]);

    test('the sentence, today, and only names and kinds', () {
      expect(body['text'], 'gastei 50');
      expect(body['today'], '2026-10-11');
      expect(body['accounts'], [
        {'id': 'a2', 'name': 'Nubank', 'card': true},
      ]);
    });

    test('never the balances', () {
      expect(body.toString().contains('184335'), isFalse);
    });

    test('archived categories stay out', () {
      expect((body['categories'] as List).length, 1);
    });
  });

  group('AiRepositoryImpl', () {
    late MockRemote remote;
    late AiRepositoryImpl repository;

    setUp(() {
      remote = MockRemote();
      repository = AiRepositoryImpl(remote);
    });

    test('an answer of the AI that is not a draft keeps its reason', () async {
      when(() => remote.isEnabled()).thenThrow(const AiException('ai_limit'));

      final result = await repository.isEnabled();

      expect(result.fold((f) => f, (_) => null), const RuleFailure('ai_limit'));
    });
  });

  group('messages', () {
    test('each reason has words the person understands', () {
      expect(aiFailureMessage(const RuleFailure('ai_disabled')), contains('Configurações'));
      expect(aiFailureMessage(const RuleFailure('ai_limit')), contains('Amanhã'));
      expect(aiFailureMessage(const RuleFailure('ai_not_understood')), contains('gastei 50'));
      expect(aiFailureMessage(const NetworkFailure('x')), contains('internet'));
      expect(aiFailureMessage(const RuleFailure('ai_unavailable')), contains('Tente de novo'));
    });
  });
}
