import 'package:flutter_test/flutter_test.dart';
import 'package:astro_app/main.dart';

void main() {
  testWidgets('App has title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Astro App'), findsOneWidget);
  });
}
