import 'package:bloc_test/bloc_test.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/data_export/presentation/cubit/data_export_cubit.dart';
import 'package:finly/features/data_export/presentation/cubit/data_export_state.dart';
import 'package:finly/features/data_export/presentation/data_export_messages.dart';
import 'package:finly/features/data_export/presentation/widgets/data_export_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDataExportCubit extends MockCubit<DataExportState> implements DataExportCubit {}

void main() {
  late MockDataExportCubit cubit;

  setUp(() {
    cubit = MockDataExportCubit();
    when(() => cubit.export()).thenAnswer((_) async {});
  });

  Future<void> show(
    WidgetTester tester,
    DataExportState state, {
    Stream<DataExportState>? later,
  }) async {
    whenListen(cubit, later ?? const Stream<DataExportState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<DataExportCubit>.value(
              value: cubit,
              child: const DataExportSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the section and the button', (tester) async {
    await show(tester, const DataExportState());

    expect(find.text('Meus dados'), findsOneWidget);
    expect(find.text('Exportar meus dados'), findsOneWidget);
    expect(find.textContaining('JSON'), findsOneWidget);
  });

  testWidgets('asks before exporting, and warns the file is not encrypted', (tester) async {
    await show(tester, const DataExportState());

    await tester.tap(find.text('Exportar meus dados'));
    await tester.pumpAndSettle();

    expect(find.text('Exportar meus dados?'), findsOneWidget);
    expect(find.textContaining('sem criptografia'), findsOneWidget);
    verifyNever(() => cubit.export());
  });

  testWidgets('exports after the person confirms', (tester) async {
    await show(tester, const DataExportState());

    await tester.tap(find.text('Exportar meus dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();

    verify(() => cubit.export()).called(1);
  });

  testWidgets('does nothing when the person cancels', (tester) async {
    await show(tester, const DataExportState());

    await tester.tap(find.text('Exportar meus dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => cubit.export());
    expect(find.text('Exportar meus dados?'), findsNothing);
  });

  testWidgets('shows a spinner and ignores taps while exporting', (tester) async {
    await show(tester, const DataExportState(status: DataExportStatus.exporting));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // A spinner never stops animating, so pumpAndSettle would time out.
    await tester.tap(find.text('Exportar meus dados'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Exportar meus dados?'), findsNothing);
  });

  testWidgets('says when the export failed', (tester) async {
    await show(
      tester,
      const DataExportState(),
      later: Stream.value(const DataExportState(
        status: DataExportStatus.failure,
        failure: NetworkFailure('network_error'),
      )),
    );
    await tester.pump();

    expect(find.textContaining('conexão'), findsOneWidget);
  });

  testWidgets('says when the file holds only a part of the data', (tester) async {
    await show(
      tester,
      const DataExportState(),
      later: Stream.value(const DataExportState(
        status: DataExportStatus.done,
        rowCount: 100000,
        truncated: true,
      )),
    );
    await tester.pump();

    expect(find.text(dataExportTruncatedMessage), findsOneWidget);
  });

  testWidgets('says nothing when the export worked', (tester) async {
    await show(
      tester,
      const DataExportState(),
      later: Stream.value(const DataExportState(status: DataExportStatus.done, rowCount: 10)),
    );
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
