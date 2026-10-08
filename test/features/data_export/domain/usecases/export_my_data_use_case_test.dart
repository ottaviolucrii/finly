import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/data_export/domain/entities/data_export_result.dart';
import 'package:finly/features/data_export/domain/entities/user_data_snapshot.dart';
import 'package:finly/features/data_export/domain/repositories/data_export_repository.dart';
import 'package:finly/features/data_export/domain/usecases/export_my_data_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements DataExportRepository {}

void main() {
  late MockRepository repository;
  late ExportMyDataUseCase useCase;

  final now = DateTime(2026, 10, 7, 9, 30);

  setUp(() {
    repository = MockRepository();
    useCase = ExportMyDataUseCase(repository, clock: () => now);
  });

  void stub(Either<Failure, UserDataSnapshot> result) {
    when(() => repository.readAll()).thenAnswer((_) async => result);
  }

  Map<String, dynamic> decode(DataExportResult file) {
    return jsonDecode(utf8.decode(file.bytes)) as Map<String, dynamic>;
  }

  Future<DataExportResult> exported(UserDataSnapshot snapshot) async {
    stub(Right(snapshot));
    final result = await useCase(const NoParams());
    return result.getOrElse(() => throw StateError('expected a file'));
  }

  test('names the file after the day of the export', () async {
    final file = await exported(const UserDataSnapshot(userId: 'u1'));

    expect(file.fileName, 'finly-meus-dados-2026-10-07.json');
  });

  test('the file is a JSON document the app can read back', () async {
    final file = await exported(const UserDataSnapshot(userId: 'u1', email: 'ana@exemplo.com'));

    final document = decode(file);
    expect(document['app'], 'Finly');
    expect((document['account'] as Map)['email'], 'ana@exemplo.com');
  });

  test('keeps accents and symbols (UTF-8)', () async {
    final file = await exported(const UserDataSnapshot(
      userId: 'u1',
      workspaces: [
        {'id': 'w1', 'name': 'Açaí & Cia — 100% "ótima"'},
      ],
    ));

    final workspace = (decode(file)['workspaces'] as List).single as Map;
    expect(workspace['name'], 'Açaí & Cia — 100% "ótima"');
  });

  test('the text is indented, so a person can read it', () async {
    final file = await exported(const UserDataSnapshot(userId: 'u1'));

    expect(utf8.decode(file.bytes), contains('\n  "app": "Finly"'));
  });

  test('counts the rows', () async {
    final file = await exported(const UserDataSnapshot(
      userId: 'u1',
      accounts: [{'id': 'a1'}, {'id': 'a2'}],
      transactions: [{'id': 't1'}],
    ));

    expect(file.rowCount, 3);
    expect(file.truncated, isFalse);
  });

  test('says when a table was cut', () async {
    final file = await exported(const UserDataSnapshot(
      userId: 'u1',
      truncatedTables: {'transactions'},
    ));

    expect(file.truncated, isTrue);
    expect(decode(file)['truncated_tables'], ['transactions']);
  });

  test('the date inside the file is the time of the export, in UTC', () async {
    final file = await exported(const UserDataSnapshot(userId: 'u1'));

    expect(decode(file)['exported_at'], now.toUtc().toIso8601String());
  });

  test('keeps the money in cents as whole numbers', () async {
    final file = await exported(const UserDataSnapshot(
      userId: 'u1',
      workspaces: [{'id': 'w1'}],
      transactions: [
        {'id': 't1', 'workspace_id': 'w1', 'occurred_at': '2026-10-01T12:00:00Z', 'amount_cents': 2590},
      ],
    ));

    final workspace = (decode(file)['workspaces'] as List).single as Map;
    final transaction = (workspace['transactions'] as List).single as Map;
    expect(transaction['amount_cents'], 2590);
  });

  test('passes a failure through unchanged', () async {
    stub(const Left(NetworkFailure('network_error')));

    final result = await useCase(const NoParams());

    expect(result, const Left<Failure, DataExportResult>(NetworkFailure('network_error')));
  });
}
