import 'package:finly/features/data_export/domain/entities/user_data_snapshot.dart';
import 'package:finly/features/data_export/domain/export_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final exportedAt = DateTime.utc(2026, 10, 7, 12, 30);

  Map<String, dynamic> doc(UserDataSnapshot data) => buildExportDocument(data, exportedAt);

  List<Map<String, dynamic>> workspacesOf(Map<String, dynamic> document) {
    return (document['workspaces'] as List).cast<Map<String, dynamic>>();
  }

  final personal = <String, dynamic>{'id': 'w1', 'name': 'Pessoal', 'type': 'personal'};
  final business = <String, dynamic>{'id': 'w2', 'name': 'Empresa', 'type': 'business'};

  group('exportFileName', () {
    test('has the date of the export', () {
      expect(exportFileName(DateTime(2026, 10, 7)), 'finly-meus-dados-2026-10-07.json');
    });

    test('pads the month and the day', () {
      expect(exportFileName(DateTime(2026, 3, 5)), 'finly-meus-dados-2026-03-05.json');
    });
  });

  group('buildExportDocument', () {
    test('says what the file is', () {
      final document = doc(const UserDataSnapshot(userId: 'u1'));

      expect(document['app'], 'Finly');
      expect(document['format_version'], exportFormatVersion);
      expect(document['exported_at'], '2026-10-07T12:30:00.000Z');
    });

    test('writes the time in UTC', () {
      final document = buildExportDocument(
        const UserDataSnapshot(userId: 'u1'),
        DateTime.utc(2026, 1, 2, 3, 4, 5),
      );

      expect(document['exported_at'], endsWith('Z'));
    });

    test('explains that money is in cents', () {
      final notes = (doc(const UserDataSnapshot(userId: 'u1'))['notes'] as List).join(' ');

      expect(notes, contains('centavos'));
    });

    test('has who the user is', () {
      final document = doc(UserDataSnapshot(
        userId: 'u1',
        email: 'ana@exemplo.com',
        profile: const {'id': 'u1', 'full_name': 'Ana Souza', 'created_at': '2026-01-05T10:00:00Z'},
      ));

      expect(document['account'], {
        'id': 'u1',
        'email': 'ana@exemplo.com',
        'full_name': 'Ana Souza',
        'created_at': '2026-01-05T10:00:00Z',
      });
    });

    test('works when there is no profile yet', () {
      final document = doc(const UserDataSnapshot(userId: 'u1', email: 'a@b.com'));

      expect((document['account'] as Map)['full_name'], isNull);
      expect(document['profile'], isNull);
      expect(document['settings'], isNull);
    });

    test('keeps the settings as they are', () {
      final document = doc(const UserDataSnapshot(
        userId: 'u1',
        settings: {'theme': 'dark', 'notification_prefs': {'bill_reminder': true}},
      ));

      expect(document['settings'], {'theme': 'dark', 'notification_prefs': {'bill_reminder': true}});
    });

    test('an empty snapshot gives an empty list of workspaces', () {
      final document = doc(const UserDataSnapshot(userId: 'u1'));

      expect(document['workspaces'], isEmpty);
      expect(document['transfers'], isEmpty);
      expect(document['truncated_tables'], isEmpty);
    });

    test('puts each thing under its own workspace', () {
      final document = doc(UserDataSnapshot(
        userId: 'u1',
        workspaces: [personal, business],
        accounts: const [
          {'id': 'a1', 'workspace_id': 'w1', 'name': 'Nubank'},
          {'id': 'a2', 'workspace_id': 'w2', 'name': 'Conta PJ'},
        ],
        categories: const [
          {'id': 'c1', 'workspace_id': 'w1', 'name': 'Mercado'},
          {'id': 'c2', 'workspace_id': 'w2', 'name': 'Impostos'},
        ],
        budgets: const [
          {'id': 'b1', 'workspace_id': 'w1', 'limit_cents': 80000},
        ],
        recurring: const [
          {'id': 'r1', 'workspace_id': 'w2', 'description': 'Aluguel'},
        ],
        transactions: const [
          {'id': 't1', 'workspace_id': 'w1', 'occurred_at': '2026-10-01T12:00:00Z'},
          {'id': 't2', 'workspace_id': 'w2', 'occurred_at': '2026-10-02T12:00:00Z'},
        ],
      ));

      final workspaces = workspacesOf(document);
      expect(workspaces.map((w) => w['name']), ['Pessoal', 'Empresa']);

      List ids(Map<String, dynamic> w, String key) => (w[key] as List).map((r) => (r as Map)['id']).toList();
      expect(ids(workspaces[0], 'accounts'), ['a1']);
      expect(ids(workspaces[1], 'accounts'), ['a2']);
      expect(ids(workspaces[0], 'categories'), ['c1']);
      expect(ids(workspaces[1], 'categories'), ['c2']);
      expect(ids(workspaces[0], 'budgets'), ['b1']);
      expect(ids(workspaces[1], 'budgets'), isEmpty);
      expect(ids(workspaces[1], 'recurring_transactions'), ['r1']);
      expect(ids(workspaces[0], 'transactions'), ['t1']);
      expect(ids(workspaces[1], 'transactions'), ['t2']);
    });

    test('keeps the columns of the workspace itself', () {
      final document = doc(UserDataSnapshot(userId: 'u1', workspaces: [personal]));

      final workspace = workspacesOf(document).single;
      expect(workspace['id'], 'w1');
      expect(workspace['type'], 'personal');
    });

    test('puts card details and invoices under the workspace of their account', () {
      final document = doc(UserDataSnapshot(
        userId: 'u1',
        workspaces: [personal, business],
        accounts: const [
          {'id': 'a1', 'workspace_id': 'w1', 'type': 'checking'},
          {'id': 'card1', 'workspace_id': 'w1', 'type': 'credit_card'},
          {'id': 'card2', 'workspace_id': 'w2', 'type': 'credit_card'},
        ],
        cardDetails: const [
          {'account_id': 'card1', 'limit_cents': 500000},
          {'account_id': 'card2', 'limit_cents': 900000},
        ],
        invoices: const [
          {'id': 'i1', 'account_id': 'card1'},
          {'id': 'i2', 'account_id': 'card2'},
          {'id': 'i3', 'account_id': 'card2'},
        ],
      ));

      final workspaces = workspacesOf(document);
      expect((workspaces[0]['credit_cards'] as List).map((r) => (r as Map)['limit_cents']), [500000]);
      expect((workspaces[1]['credit_cards'] as List).map((r) => (r as Map)['limit_cents']), [900000]);
      expect((workspaces[0]['credit_card_invoices'] as List).map((r) => (r as Map)['id']), ['i1']);
      expect((workspaces[1]['credit_card_invoices'] as List).map((r) => (r as Map)['id']), ['i2', 'i3']);
    });

    test('a card detail of an unknown account goes nowhere', () {
      final document = doc(UserDataSnapshot(
        userId: 'u1',
        workspaces: [personal],
        accounts: const [{'id': 'a1', 'workspace_id': 'w1'}],
        cardDetails: const [{'account_id': 'ghost', 'limit_cents': 1}],
      ));

      expect(workspacesOf(document).single['credit_cards'], isEmpty);
    });

    test('sorts the transactions by date, oldest first', () {
      final document = doc(UserDataSnapshot(
        userId: 'u1',
        workspaces: [personal],
        transactions: const [
          {'id': 'late', 'workspace_id': 'w1', 'occurred_at': '2026-10-09T12:00:00Z'},
          {'id': 'early', 'workspace_id': 'w1', 'occurred_at': '2026-10-01T12:00:00Z'},
          {'id': 'middle', 'workspace_id': 'w1', 'occurred_at': '2026-10-05T12:00:00Z'},
        ],
      ));

      final transactions = workspacesOf(document).single['transactions'] as List;
      expect(transactions.map((t) => (t as Map)['id']), ['early', 'middle', 'late']);
    });

    test('transactions of the same moment keep a stable order', () {
      final document = doc(UserDataSnapshot(
        userId: 'u1',
        workspaces: [personal],
        transactions: const [
          {'id': 'b', 'workspace_id': 'w1', 'occurred_at': '2026-10-01T12:00:00Z'},
          {'id': 'a', 'workspace_id': 'w1', 'occurred_at': '2026-10-01T12:00:00Z'},
        ],
      ));

      final transactions = workspacesOf(document).single['transactions'] as List;
      expect(transactions.map((t) => (t as Map)['id']), ['a', 'b']);
    });

    test('keeps the deleted transactions, with their deleted_at', () {
      final document = doc(UserDataSnapshot(
        userId: 'u1',
        workspaces: [personal],
        transactions: const [
          {'id': 't1', 'workspace_id': 'w1', 'occurred_at': '2026-10-01T12:00:00Z', 'deleted_at': '2026-10-03T08:00:00Z'},
        ],
      ));

      final transaction = (workspacesOf(document).single['transactions'] as List).single as Map;
      expect(transaction['deleted_at'], '2026-10-03T08:00:00Z');
    });

    test('a row of a workspace that is not there is left out', () {
      final document = doc(UserDataSnapshot(
        userId: 'u1',
        workspaces: [personal],
        accounts: const [{'id': 'a9', 'workspace_id': 'other'}],
      ));

      expect(workspacesOf(document).single['accounts'], isEmpty);
    });

    test('does not change the rows it is given', () {
      final rows = <Map<String, dynamic>>[
        {'id': 'z', 'workspace_id': 'w1', 'occurred_at': '2026-10-09T12:00:00Z'},
        {'id': 'y', 'workspace_id': 'w1', 'occurred_at': '2026-10-01T12:00:00Z'},
      ];

      doc(UserDataSnapshot(userId: 'u1', workspaces: [personal], transactions: rows));

      expect(rows.first['id'], 'z');
    });

    test('lists the transfers at the top level', () {
      final document = doc(const UserDataSnapshot(
        userId: 'u1',
        transfers: [{'id': 'x1', 'kind': 'internal'}],
      ));

      expect((document['transfers'] as List).single, {'id': 'x1', 'kind': 'internal'});
    });

    test('lists the tables that were cut, sorted', () {
      final document = doc(const UserDataSnapshot(
        userId: 'u1',
        truncatedTables: {'transactions', 'budgets'},
      ));

      expect(document['truncated_tables'], ['budgets', 'transactions']);
    });
  });

  group('UserDataSnapshot.rowCount', () {
    test('is zero for nothing', () {
      expect(const UserDataSnapshot(userId: 'u1').rowCount, 0);
    });

    test('counts every row of every table, the profile and the settings', () {
      final snapshot = UserDataSnapshot(
        userId: 'u1',
        profile: const {'id': 'u1'},
        settings: const {'user_id': 'u1'},
        workspaces: [personal],
        accounts: const [{'id': 'a1'}, {'id': 'a2'}],
        transactions: const [{'id': 't1'}, {'id': 't2'}, {'id': 't3'}],
      );

      expect(snapshot.rowCount, 2 + 1 + 2 + 3);
    });
  });
}
