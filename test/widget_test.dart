import 'package:flutter_test/flutter_test.dart';
import 'package:unidrive/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UniDriveApp());
    expect(find.byType(UniDriveApp), findsOneWidget);
  });
}
