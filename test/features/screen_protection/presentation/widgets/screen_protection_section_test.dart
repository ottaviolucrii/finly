import 'package:bloc_test/bloc_test.dart';
import 'package:finly/features/screen_protection/presentation/cubit/screen_protection_cubit.dart';
import 'package:finly/features/screen_protection/presentation/cubit/screen_protection_state.dart';
import 'package:finly/features/screen_protection/presentation/widgets/screen_protection_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCubit0 extends MockCubit<ScreenProtectionState> implements ScreenProtectionCubit {}

void main() {
  late MockCubit0 cubit;

  setUp(() {
    cubit = MockCubit0();
    when(() => cubit.setEnabled(any())).thenAnswer((_) async {});
  });

  Future<void> show(
    WidgetTester tester,
    ScreenProtectionState state, {
    Stream<ScreenProtectionState>? later,
  }) async {
    whenListen(cubit, later ?? const Stream<ScreenProtectionState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<ScreenProtectionCubit>.value(
            value: cubit,
            child: const ScreenProtectionSection(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const ready = ScreenProtectionState(status: ScreenProtectionStatus.ready);

  testWidgets('shows the section and the switch, off', (tester) async {
    await show(tester, ready);

    expect(find.text('Privacidade'), findsOneWidget);
    expect(find.text('Bloquear capturas de tela'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
  });

  testWidgets('shows the switch on, and tells how to take a print', (tester) async {
    await show(tester, const ScreenProtectionState(status: ScreenProtectionStatus.ready, enabled: true));

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(find.textContaining('Desligue para tirar um print'), findsOneWidget);
  });

  testWidgets('turning the switch on asks the cubit', (tester) async {
    await show(tester, ready);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    verify(() => cubit.setEnabled(true)).called(1);
  });

  testWidgets('turning the switch off asks the cubit', (tester) async {
    await show(tester, const ScreenProtectionState(status: ScreenProtectionStatus.ready, enabled: true));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    verify(() => cubit.setEnabled(false)).called(1);
  });

  testWidgets('the switch is off while the phone has not been read', (tester) async {
    await show(tester, const ScreenProtectionState());

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
  });

  testWidgets('the switch is off while a change is being saved', (tester) async {
    await show(
      tester,
      const ScreenProtectionState(status: ScreenProtectionStatus.ready, enabled: true, saving: true),
    );

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
  });

  testWidgets('shows nothing on a phone that cannot block screenshots', (tester) async {
    await show(tester, const ScreenProtectionState(status: ScreenProtectionStatus.unsupported));

    expect(find.text('Privacidade'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('says when the change was refused', (tester) async {
    await show(
      tester,
      ready,
      later: Stream.value(
        const ScreenProtectionState(status: ScreenProtectionStatus.ready, failed: true),
      ),
    );
    await tester.pump();

    expect(find.text('Não foi possível mudar. Tente de novo.'), findsOneWidget);
  });
}
