import 'package:bloc_test/bloc_test.dart';
import 'package:finly/features/lock/domain/attempt_limiter.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:finly/features/lock/presentation/widgets/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppLockCubit extends MockCubit<AppLockState> implements AppLockCubit {}

void main() {
  late MockAppLockCubit cubit;

  setUp(() {
    cubit = MockAppLockCubit();
    when(() => cubit.unlockWithDevice()).thenAnswer((_) async {});
    when(() => cubit.unlockWithPassword(any())).thenAnswer((_) async {});
  });

  Future<void> show(
    WidgetTester tester,
    AppLockState state, {
    VoidCallback? onSignOut,
  }) async {
    whenListen(cubit, const Stream<AppLockState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<AppLockCubit>.value(
            value: cubit,
            child: LockScreen(onSignOut: onSignOut ?? () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Removes the screen, so its timers are cancelled before the test ends.
  Future<void> close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('shows the title, the password field and the sign-out button', (tester) async {
    await show(tester, const AppLockState(signedIn: true));

    expect(find.text('Finly bloqueado'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Entrar com a senha'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);
    await close(tester);
  });

  testWidgets('offers the phone prompt only when the phone can do it', (tester) async {
    await show(tester, const AppLockState(signedIn: true));
    expect(find.text('Usar biometria ou PIN do aparelho'), findsNothing);
    await close(tester);

    await show(tester, const AppLockState(signedIn: true, deviceSupported: true));
    expect(find.text('Usar biometria ou PIN do aparelho'), findsOneWidget);
    await close(tester);
  });

  testWidgets('tapping the phone button asks the phone', (tester) async {
    await show(tester, const AppLockState(signedIn: true, deviceSupported: true));

    await tester.tap(find.text('Usar biometria ou PIN do aparelho'));
    await tester.pump();

    verify(() => cubit.unlockWithDevice()).called(1);
    await close(tester);
  });

  testWidgets('sends the typed password', (tester) async {
    await show(tester, const AppLockState(signedIn: true));

    await tester.enterText(find.byType(TextField), 'segredo123');
    await tester.tap(find.text('Entrar com a senha'));
    await tester.pump();

    verify(() => cubit.unlockWithPassword('segredo123')).called(1);
    await close(tester);
  });

  testWidgets('does not send an empty password', (tester) async {
    await show(tester, const AppLockState(signedIn: true));

    await tester.tap(find.text('Entrar com a senha'));
    await tester.pump();

    verifyNever(() => cubit.unlockWithPassword(any()));
    await close(tester);
  });

  testWidgets('a wrong password says how many tries are left', (tester) async {
    await show(
      tester,
      const AppLockState(signedIn: true, error: LockError.wrongPassword, attemptsLeft: 3),
    );

    expect(find.text('Senha incorreta. Restam 3 tentativas.'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a block shows the countdown and turns the button off', (tester) async {
    await show(
      tester,
      AppLockState(
        signedIn: true,
        error: LockError.blocked,
        attemptsLeft: 0,
        blockedUntil: DateTime.now().add(const Duration(minutes: 4, seconds: 30)),
      ),
    );

    expect(find.textContaining('Muitas tentativas erradas'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await close(tester);
  });

  testWidgets('asks for the fingerprint by itself when it is turned on', (tester) async {
    await show(
      tester,
      const AppLockState(
        signedIn: true,
        settingsReady: true,
        deviceSupported: true,
        settings: LockSettings(biometricEnabled: true),
      ),
    );

    verify(() => cubit.unlockWithDevice()).called(1);
    await close(tester);
  });

  testWidgets('does not ask by itself when biometrics are off', (tester) async {
    await show(
      tester,
      const AppLockState(signedIn: true, settingsReady: true, deviceSupported: true),
    );

    verifyNever(() => cubit.unlockWithDevice());
    await close(tester);
  });

  testWidgets('does not ask by itself before the settings are known', (tester) async {
    await show(
      tester,
      const AppLockState(
        signedIn: true,
        deviceSupported: true,
        settings: LockSettings(biometricEnabled: true),
      ),
    );

    verifyNever(() => cubit.unlockWithDevice());
    await close(tester);
  });

  testWidgets('the sign-out button calls its callback', (tester) async {
    var signedOut = 0;
    await show(tester, const AppLockState(signedIn: true), onSignOut: () => signedOut++);

    await tester.tap(find.text('Sair da conta'));
    await tester.pump();

    expect(signedOut, 1);
    await close(tester);
  });

  testWidgets('shows all five tries at the start', (tester) async {
    await show(tester, const AppLockState(signedIn: true));

    expect(const AppLockState().attemptsLeft, AttemptLimiter.maxFailures);
    expect(find.textContaining('Senha incorreta'), findsNothing);
    await close(tester);
  });
}
