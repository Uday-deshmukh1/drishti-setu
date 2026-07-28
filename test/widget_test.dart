import 'package:flutter_test/flutter_test.dart';
import 'package:drishti_setu/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const DrishtiSetuApp());
    expect(find.text('Drishti Setu'), findsOneWidget);
  });
}
