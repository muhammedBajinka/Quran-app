import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/main.dart';

void main() {
  testWidgets('Quran app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const QuranApp());

    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('Quran Home'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
