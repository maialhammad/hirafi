
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_90/main.dart';

void main() {
  testWidgets('Hirafi app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const HirafiApp());

    expect(find.text('Welcome to Hirafi'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
