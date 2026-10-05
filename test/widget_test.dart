import 'package:finly/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts and shows the Finly placeholder', (tester) async {
    await tester.pumpWidget(const FinlyApp());

    expect(find.text('Finly'), findsOneWidget);
  });
}