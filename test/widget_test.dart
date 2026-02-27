import 'package:flutter_test/flutter_test.dart';
import 'package:vital_sync/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VitalSyncApp());

    expect(find.text('VitalSync'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
