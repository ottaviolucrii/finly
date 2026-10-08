import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/data/datasources/audit_remote_data_source.dart';
import 'package:finly/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements AuditRemoteDataSource {}

void main() {
  group('auditRecordFromRow', () {
    // The real shape of a row: the id of the log is a number (bigint).
    final row = <String, dynamic>{
      'id': 4021,
      'table_name': 'transactions',
      'record_id': 'ed36cb62-3ed6-408b-b061-78d2e0aba047',
      'action': 'UPDATE',
      'old_data': {'amount_cents': 100},
      'new_data': {'amount_cents': 200},
      'occurred_at': '2026-10-07T23:26:44.57483+00:00',
      'changed_by': 'u1',
    };

    test('reads a line of the log', () {
      final record = auditRecordFromRow(row);

      expect(record.id, '4021');
      expect(record.tableName, 'transactions');
      expect(record.recordId, 'ed36cb62-3ed6-408b-b061-78d2e0aba047');
      expect(record.action, AuditAction.update);
      expect(record.oldData, {'amount_cents': 100});
      expect(record.newData, {'amount_cents': 200});
      expect(record.occurredAt, DateTime.utc(2026, 10, 7, 23, 26, 44, 574, 830));
    });

    test('an id that is text works too', () {
      final record = auditRecordFromRow({...row, 'id': 'r1', 'record_id': 't1'});

      expect(record.id, 'r1');
      expect(record.recordId, 't1');
    });

    test('a missing id is an error, not the text "null"', () {
      final broken = {...row}..remove('id');

      expect(() => auditRecordFromRow(broken), throwsFormatException);
    });

    test('a missing record id is an error too', () {
      expect(() => auditRecordFromRow({...row, 'record_id': null}), throwsFormatException);
    });

    test('an INSERT has no old row', () {
      final record = auditRecordFromRow({...row, 'action': 'INSERT', 'old_data': null});

      expect(record.action, AuditAction.insert);
      expect(record.oldData, isNull);
    });

    test('a DELETE has no new row', () {
      final record = auditRecordFromRow({...row, 'action': 'DELETE', 'new_data': null});

      expect(record.action, AuditAction.delete);
      expect(record.newData, isNull);
    });

    test('the rows are copied as maps of text to anything', () {
      final record = auditRecordFromRow({
        ...row,
        'new_data': <Object?, Object?>{'name': 'XP', 'archived_at': null},
      });

      expect(record.newData, {'name': 'XP', 'archived_at': null});
    });

    test('an action it does not know is an error, not a guess', () {
      expect(() => auditRecordFromRow({...row, 'action': 'TRUNCATE'}), throwsArgumentError);
    });

    test('a missing column is an error', () {
      final broken = {...row}..remove('table_name');

      expect(() => auditRecordFromRow(broken), throwsA(isA<TypeError>()));
    });
  });

  group('AuditRepositoryImpl', () {
    late MockRemote remote;
    late AuditRepositoryImpl repository;

    setUpAll(() => registerFallbackValue(AuditFilter.all));

    setUp(() {
      remote = MockRemote();
      repository = AuditRepositoryImpl(remote);
    });

    test('returns the records the data source read', () async {
      final records = [
        AuditRecord(
          id: 'r1',
          tableName: 'accounts',
          recordId: 'a1',
          action: AuditAction.insert,
          occurredAt: DateTime.utc(2026, 10, 7),
        ),
      ];
      when(() => remote.getRecords('w1', offset: 0, limit: 30, filter: AuditFilter.all))
          .thenAnswer((_) async => records);

      final result = await repository.getRecords('w1', offset: 0, limit: 30);

      expect(result, Right<Failure, List<AuditRecord>>(records));
    });

    test('forwards the filter and the page', () async {
      when(() => remote.getRecords(any(), offset: any(named: 'offset'), limit: any(named: 'limit'), filter: any(named: 'filter')))
          .thenAnswer((_) async => const []);

      await repository.getRecords('w1', offset: 60, limit: 30, filter: AuditFilter.budgets);

      verify(() => remote.getRecords('w1', offset: 60, limit: 30, filter: AuditFilter.budgets)).called(1);
    });

    test('returns the names the data source read', () async {
      const lookup = AuditLookup(accountNames: {'a1': 'C6'});
      when(() => remote.getLookup('w1')).thenAnswer((_) async => lookup);

      final result = await repository.getLookup('w1');

      expect(result, const Right<Failure, AuditLookup>(lookup));
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.getRecords(any(), offset: any(named: 'offset'), limit: any(named: 'limit'), filter: any(named: 'filter')))
          .thenThrow(TimeoutException('slow'));

      final result = await repository.getRecords('w1', offset: 0, limit: 30);

      expect(result, const Left<Failure, List<AuditRecord>>(NetworkFailure('network_error')));
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.getLookup(any())).thenThrow(StateError('boom'));

      final result = await repository.getLookup('w1');

      expect(result, const Left<Failure, AuditLookup>(ServerFailure('unknown_error')));
    });

    test('a line the app cannot read becomes a failure instead of escaping', () async {
      when(() => remote.getRecords(any(), offset: any(named: 'offset'), limit: any(named: 'limit'), filter: any(named: 'filter')))
          .thenAnswer((_) async => throw ArgumentError('TRUNCATE'));

      final result = await repository.getRecords('w1', offset: 0, limit: 30);

      expect(result.isLeft(), isTrue);
    });
  });
}
