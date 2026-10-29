import 'package:flutter_test/flutter_test.dart';
import 'package:love21_flutter/love21_app.dart';

void main() {
  testWidgets('welcome screen shows the Love 21 entry points', (tester) async {
    await tester.pumpWidget(const Love21App());
    expect(find.text('Meaningful love, unhurried'), findsOneWidget);
    expect(find.text('Start your journey'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
