import 'package:bloc_test/bloc_test.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_state.dart';
import 'package:finly/features/reminders/presentation/widgets/notifications_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemindersCubit extends MockCubit<RemindersState> implements RemindersCubit {}

void main() {
  late MockRemindersCubit cubit;

  setUp(() {
    cubit = MockRemindersCubit();
    when(() => cubit.refresh()).thenAnswer((_) async {});
    when(() => cubit.setBillReminder(any())).thenAnswer((_) async {});
    when(() => cubit.setCardDue(any())).thenAnswer((_) async {});
    when(() => cubit.schedule()).thenAnswer((_) async {});
    when(() => cubit.requestPermission()).thenAnswer((_) async {});
    when(() => cubit.sendTest()).thenAnswer((_) async {});
  });

  Future<void> show(WidgetTester tester, RemindersState state) async {
    whenListen(cubit, const Stream<RemindersState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<RemindersCubit>.value(
              value: cubit,
              child: const NotificationsSettingsCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the section and its rows', (tester) async {
    await show(tester, const RemindersState(prefsReady: true, permissionGranted: true));

    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Contas a pagar'), findsOneWidget);
    expect(find.text('Fatura do cartão'), findsOneWidget);
    expect(find.text('Atualizar lembretes'), findsOneWidget);
    expect(find.text('Enviar notificação de teste'), findsOneWidget);
  });

  testWidgets('reads the settings when it opens', (tester) async {
    await show(tester, const RemindersState());

    verify(() => cubit.refresh()).called(1);
  });

  testWidgets('does not ask for the permission when it is already granted', (tester) async {
    await show(tester, const RemindersState(prefsReady: true, permissionGranted: true));

    expect(find.text('Ativar notificações'), findsNothing);
  });

  testWidgets('asks for the permission when it is missing', (tester) async {
    await show(tester, const RemindersState(prefsReady: true, permissionGranted: false));

    expect(find.text('Ativar notificações'), findsOneWidget);
  });

  testWidgets('the Ativar button asks for the permission', (tester) async {
    await show(tester, const RemindersState(prefsReady: true, permissionGranted: false));

    await tester.tap(find.text('Ativar'));
    await tester.pump();

    verify(() => cubit.requestPermission()).called(1);
  });

  testWidgets('the switches show the preferences', (tester) async {
    await show(
      tester,
      const RemindersState(
        prefsReady: true,
        permissionGranted: true,
        prefs: NotificationPrefs(billReminder: false, cardDue: true),
      ),
    );

    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches[0].value, isFalse);
    expect(switches[1].value, isTrue);
  });

  testWidgets('the switches are off limits until the preferences are read', (tester) async {
    await show(tester, const RemindersState());

    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect(switches.every((s) => s.onChanged == null), isTrue);
  });

  testWidgets('tapping the bills switch changes it', (tester) async {
    await show(tester, const RemindersState(prefsReady: true, permissionGranted: true));

    await tester.tap(find.text('Contas a pagar'));
    await tester.pump();

    verify(() => cubit.setBillReminder(false)).called(1);
  });

  testWidgets('tapping the invoices switch changes it', (tester) async {
    await show(tester, const RemindersState(prefsReady: true, permissionGranted: true));

    await tester.tap(find.text('Fatura do cartão'));
    await tester.pump();

    verify(() => cubit.setCardDue(false)).called(1);
  });

  testWidgets('shows how many reminders are scheduled', (tester) async {
    await show(
      tester,
      const RemindersState(prefsReady: true, permissionGranted: true, scheduledCount: 3),
    );

    expect(find.text('3 lembretes agendados'), findsOneWidget);
  });

  testWidgets('says "1 lembrete" in the singular', (tester) async {
    await show(
      tester,
      const RemindersState(prefsReady: true, permissionGranted: true, scheduledCount: 1),
    );

    expect(find.text('1 lembrete agendado'), findsOneWidget);
  });

  testWidgets('says it is updating while it syncs', (tester) async {
    await show(
      tester,
      const RemindersState(
        prefsReady: true,
        permissionGranted: true,
        status: RemindersStatus.syncing,
      ),
    );

    expect(find.text('Atualizando...'), findsOneWidget);
  });

  testWidgets('Atualizar lembretes rebuilds the schedule', (tester) async {
    await show(tester, const RemindersState(prefsReady: true, permissionGranted: true));

    await tester.tap(find.text('Atualizar lembretes'));
    await tester.pump();

    verify(() => cubit.schedule()).called(1);
  });

  testWidgets('the test row sends a test notification', (tester) async {
    await show(tester, const RemindersState(prefsReady: true, permissionGranted: true));

    await tester.tap(find.text('Enviar notificação de teste'));
    await tester.pump();

    verify(() => cubit.sendTest()).called(1);
  });
}
