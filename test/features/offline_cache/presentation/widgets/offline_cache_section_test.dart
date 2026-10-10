import 'package:bloc_test/bloc_test.dart';
import 'package:finly/features/offline_cache/presentation/cubit/offline_cache_cubit.dart';
import 'package:finly/features/offline_cache/presentation/cubit/offline_cache_state.dart';
import 'package:finly/features/offline_cache/presentation/widgets/offline_cache_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOfflineCubit extends MockCubit<OfflineCacheState> implements OfflineCacheCubit {}

void main() {
  late MockOfflineCubit cubit;

  setUp(() {
    cubit = MockOfflineCubit();
    when(() => cubit.setEnabled(any())).thenAnswer((_) async {});
    when(() => cubit.erase()).thenAnswer((_) async {});
  });

  Future<void> show(
    WidgetTester tester,
    OfflineCacheState state, {
    Stream<OfflineCacheState>? later,
  }) async {
    whenListen(cubit, later ?? const Stream<OfflineCacheState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<OfflineCacheCubit>.value(
            value: cubit,
            child: const SingleChildScrollView(child: OfflineCacheSection()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const loaded = OfflineCacheState(loaded: true, enabled: true, sizeBytes: 3 * 1024 * 1024);

  testWidgets('shows the section, the switch and the size used', (tester) async {
    await show(tester, loaded);

    expect(find.text('Uso sem internet'), findsOneWidget);
    expect(find.text('Guardar dados para usar sem internet'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(find.text('Usando 3,0 MB'), findsOneWidget);
  });

  testWidgets('says plainly that the data is not encrypted and where it stays', (tester) async {
    await show(tester, loaded);

    expect(find.textContaining('só neste celular'), findsOneWidget);
    expect(find.textContaining('sem criptografia'), findsOneWidget);
  });

  testWidgets('says nothing is kept when nothing is', (tester) async {
    await show(tester, const OfflineCacheState(loaded: true));

    expect(find.text('Nada guardado'), findsOneWidget);
  });

  testWidgets('shows the switch off when the copies are off', (tester) async {
    await show(tester, const OfflineCacheState(loaded: true, enabled: false));

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
  });

  testWidgets('turning the switch off asks the cubit', (tester) async {
    await show(tester, loaded);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    verify(() => cubit.setEnabled(false)).called(1);
  });

  testWidgets('turning the switch on asks the cubit', (tester) async {
    await show(tester, const OfflineCacheState(loaded: true, enabled: false));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    verify(() => cubit.setEnabled(true)).called(1);
  });

  testWidgets('tapping "Apagar dados guardados" asks the cubit', (tester) async {
    await show(tester, loaded);

    await tester.tap(find.text('Apagar dados guardados'));
    await tester.pump();

    verify(() => cubit.erase()).called(1);
  });

  testWidgets('there is nothing to erase when nothing is kept', (tester) async {
    await show(tester, const OfflineCacheState(loaded: true));

    await tester.tap(find.text('Apagar dados guardados'));
    await tester.pump();

    verifyNever(() => cubit.erase());
  });

  testWidgets('nothing can be changed before the phone has been read', (tester) async {
    await show(tester, const OfflineCacheState());

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
  });

  testWidgets('nothing can be changed while something is going on', (tester) async {
    await show(tester, const OfflineCacheState(loaded: true, busy: true, sizeBytes: 1024));

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
    await tester.tap(find.text('Apagar dados guardados'));
    await tester.pump();
    verifyNever(() => cubit.erase());
  });

  testWidgets('says when the copies were erased', (tester) async {
    await show(
      tester,
      loaded,
      later: Stream.value(const OfflineCacheState(loaded: true, erased: 1)),
    );
    await tester.pump();

    expect(find.text('Dados guardados apagados.'), findsOneWidget);
  });

  testWidgets('says when a change was refused', (tester) async {
    await show(
      tester,
      loaded,
      later: Stream.value(const OfflineCacheState(loaded: true, failed: true)),
    );
    await tester.pump();

    expect(find.text('Não foi possível mudar. Tente de novo.'), findsOneWidget);
  });
}
