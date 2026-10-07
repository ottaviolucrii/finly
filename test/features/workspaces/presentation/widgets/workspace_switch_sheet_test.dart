import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:finly/features/lock/presentation/cubit/password_check_result.dart';
import 'package:finly/features/workspaces/presentation/widgets/workspace_switch_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const personal = WorkspaceEntity(
    id: 'w1',
    ownerId: 'u1',
    name: 'Pessoal',
    taxId: '52998224725',
    taxIdType: TaxIdType.cpf,
    type: WorkspaceType.personal,
  );
  const business = WorkspaceEntity(
    id: 'w2',
    ownerId: 'u1',
    name: 'Minha Empresa',
    taxId: '11222333000181',
    taxIdType: TaxIdType.cnpj,
    type: WorkspaceType.business,
  );

  var confirmed = 0;
  final typed = <String>[];

  setUp(() {
    confirmed = 0;
    typed.clear();
  });

  Future<void> show(
    WidgetTester tester, {
    required SwitchProtection level,
    bool deviceSupported = true,
    Future<bool> Function()? onDevice,
    Future<PasswordCheckResult> Function(String)? onCheck,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceSwitchSheet(
            from: personal,
            to: business,
            level: level,
            deviceSupported: deviceSupported,
            onConfirm: () => confirmed++,
            onConfirmWithDevice: onDevice ?? () async => true,
            onCheckPassword: onCheck ??
                (password) async {
                  typed.add(password);
                  return const PasswordCheckResult();
                },
          ),
        ),
      ),
    );
  }

  /// Removes the sheet, so its timers are cancelled before the test ends.
  Future<void> close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('shows both workspaces', (tester) async {
    await show(tester, level: SwitchProtection.confirm);

    expect(find.text('Pessoal'), findsOneWidget);
    expect(find.text('Minha Empresa'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    await close(tester);
  });

  group('confirm', () {
    testWidgets('asks only for a tap', (tester) async {
      await show(tester, level: SwitchProtection.confirm);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Confirmar com biometria ou PIN'), findsNothing);

      await tester.tap(find.text('Mudar para Minha Empresa'));
      await tester.pump();

      expect(confirmed, 1);
      await close(tester);
    });
  });

  group('biometric', () {
    testWidgets('a confirmed prompt switches, once', (tester) async {
      await show(tester, level: SwitchProtection.biometric);

      expect(find.text('Mudar para Minha Empresa'), findsNothing);
      await tester.tap(find.text('Confirmar com biometria ou PIN'));
      await tester.pump();
      await tester.pump();

      expect(confirmed, 1);
      await close(tester);
    });

    testWidgets('a prompt that is not confirmed does not switch and can be retried', (tester) async {
      await show(tester, level: SwitchProtection.biometric, onDevice: () async => false);

      await tester.tap(find.text('Confirmar com biometria ou PIN'));
      await tester.pump();
      await tester.pump();

      expect(confirmed, 0);
      expect(find.textContaining('Não foi possível confirmar'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Confirmar com biometria ou PIN'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNotNull);
      await close(tester);
    });

    testWidgets('the password is the alternative', (tester) async {
      await show(tester, level: SwitchProtection.biometric);

      await tester.tap(find.text('Usar a senha da conta'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Confirmar com biometria ou PIN'), findsNothing);
      await close(tester);
    });

    testWidgets('a phone with no biometrics goes straight to the password', (tester) async {
      await show(tester, level: SwitchProtection.biometric, deviceSupported: false);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Confirmar com biometria ou PIN'), findsNothing);
      await close(tester);
    });
  });

  group('password', () {
    testWidgets('asks for the password, not for the phone', (tester) async {
      await show(tester, level: SwitchProtection.password);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Confirmar com biometria ou PIN'), findsNothing);
      await close(tester);
    });

    testWidgets('the right password switches, once', (tester) async {
      await show(tester, level: SwitchProtection.password);

      await tester.enterText(find.byType(TextField), 'segredo123');
      await tester.tap(find.text('Mudar para Minha Empresa'));
      await tester.pump();
      await tester.pump();

      expect(typed, ['segredo123']);
      expect(confirmed, 1);
      await close(tester);
    });

    testWidgets('a wrong password never switches and says how many tries are left', (tester) async {
      await show(
        tester,
        level: SwitchProtection.password,
        onCheck: (_) async => const PasswordCheckResult(
          error: LockError.wrongPassword,
          attemptsLeft: 3,
        ),
      );

      await tester.enterText(find.byType(TextField), 'errada');
      await tester.tap(find.text('Mudar para Minha Empresa'));
      await tester.pump();
      await tester.pump();

      expect(confirmed, 0);
      expect(find.text('Senha incorreta. Restam 3 tentativas.'), findsOneWidget);
      await close(tester);
    });

    testWidgets('the password field is cleared after a try', (tester) async {
      await show(
        tester,
        level: SwitchProtection.password,
        onCheck: (_) async => const PasswordCheckResult(
          error: LockError.wrongPassword,
          attemptsLeft: 3,
        ),
      );

      await tester.enterText(find.byType(TextField), 'errada');
      await tester.tap(find.text('Mudar para Minha Empresa'));
      await tester.pump();
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
      await close(tester);
    });

    testWidgets('does not check an empty password', (tester) async {
      await show(tester, level: SwitchProtection.password);

      await tester.tap(find.text('Mudar para Minha Empresa'));
      await tester.pump();

      expect(typed, isEmpty);
      expect(confirmed, 0);
      await close(tester);
    });

    testWidgets('a block shows the countdown and turns the button off', (tester) async {
      await show(
        tester,
        level: SwitchProtection.password,
        onCheck: (_) async => PasswordCheckResult(
          error: LockError.blocked,
          attemptsLeft: 0,
          blockedUntil: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );

      await tester.enterText(find.byType(TextField), 'errada');
      await tester.tap(find.text('Mudar para Minha Empresa'));
      await tester.pump();
      await tester.pump();

      expect(confirmed, 0);
      expect(find.textContaining('Muitas tentativas erradas'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      await close(tester);
    });
  });
}
