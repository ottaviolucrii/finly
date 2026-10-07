import 'package:bloc_test/bloc_test.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_cubit.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_state.dart';
import 'package:finly/features/appearance/presentation/widgets/appearance_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppearanceCubit extends MockCubit<AppearanceState> implements AppearanceCubit {}

void main() {
  late MockAppearanceCubit cubit;

  setUpAll(() => registerFallbackValue(AppearanceMode.system));

  setUp(() {
    cubit = MockAppearanceCubit();
    when(() => cubit.setMode(any())).thenAnswer((_) async {});
  });

  Future<void> show(
    WidgetTester tester,
    AppearanceState state, {
    Stream<AppearanceState>? later,
  }) async {
    whenListen(cubit, later ?? const Stream<AppearanceState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<AppearanceCubit>.value(
              value: cubit,
              child: const AppearanceSettingsCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the section with the three choices', (tester) async {
    await show(tester, const AppearanceState());

    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
  });

  testWidgets('marks the current choice', (tester) async {
    await show(tester, const AppearanceState(mode: AppearanceMode.dark));

    final button = tester.widget<SegmentedButton<AppearanceMode>>(
      find.byType(SegmentedButton<AppearanceMode>),
    );
    expect(button.selected, {AppearanceMode.dark});
  });

  testWidgets('tapping a choice asks the cubit to change the theme', (tester) async {
    await show(tester, const AppearanceState());

    await tester.tap(find.text('Escuro'));
    await tester.pump();

    verify(() => cubit.setMode(AppearanceMode.dark)).called(1);
  });

  testWidgets('tapping Claro asks for the light theme', (tester) async {
    await show(tester, const AppearanceState(mode: AppearanceMode.dark));

    await tester.tap(find.text('Claro'));
    await tester.pump();

    verify(() => cubit.setMode(AppearanceMode.light)).called(1);
  });

  testWidgets('says when the choice could not be saved', (tester) async {
    await show(
      tester,
      const AppearanceState(),
      later: Stream.value(const AppearanceState(error: AppearanceError.saveFailed)),
    );
    await tester.pump();

    expect(find.text('Não foi possível salvar. Tente de novo.'), findsOneWidget);
  });
}
