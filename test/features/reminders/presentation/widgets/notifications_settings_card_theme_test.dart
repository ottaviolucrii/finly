import 'package:bloc_test/bloc_test.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_state.dart';
import 'package:finly/features/reminders/presentation/widgets/notifications_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemindersCubit extends MockCubit<RemindersState> implements RemindersCubit {}

void main() {
  testWidgets('the permission row fits with the full-width button theme of the app', (tester) async {
    final cubit = MockRemindersCubit();
    when(() => cubit.refresh()).thenAnswer((_) async {});
    whenListen(
      cubit,
      const Stream<RemindersState>.empty(),
      initialState: const RemindersState(prefsReady: true, permissionGranted: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),
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

    expect(tester.takeException(), isNull);
    expect(find.text('Ativar'), findsOneWidget);
  });
}