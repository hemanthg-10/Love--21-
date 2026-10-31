import 'package:flutter_test/flutter_test.dart';
import 'package:love21_flutter/love21_app.dart';

void main() {
  test('18th birthday is eligible and the day before is not', () {
    final today = DateTime(2026, 10, 31);
    expect(isAtLeastMinimumAge(DateTime(2008, 10, 31), today), isTrue);
    expect(isAtLeastMinimumAge(DateTime(2008, 11, 1), today), isFalse);
  });

  test('latest eligible date is calculated dynamically', () {
    expect(latestEligibleBirthDate(DateTime(2026, 10, 31)), DateTime(2008, 10, 31));
    expect(latestEligibleBirthDate(DateTime(2027, 1, 1)), DateTime(2009, 1, 1));
  });

  test('leap-day maximum date clamps safely in a non-leap year', () {
    expect(latestEligibleBirthDate(DateTime(2027, 2, 28)), DateTime(2009, 2, 28));
  });

  test('discovery preference is derived from registered gender only', () {
    expect(oppositeGenderPreference('Man'), 'Women');
    expect(oppositeGenderPreference('Woman'), 'Men');
    expect(oppositeGenderPreference(null), isNull);
    expect(oppositeGenderPreference('Other'), isNull);
  });

  testWidgets('welcome screen shows the Love 21 entry points', (tester) async {
    await tester.pumpWidget(const Love21App());
    expect(find.text('Meaningful love, unhurried'), findsOneWidget);
    expect(find.text('Start your journey'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
