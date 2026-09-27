import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/main.dart';
import 'package:quran_app/state/progress_state.dart';

void main() {
  testWidgets('Quran app loads', (WidgetTester tester) async {
    final progressState = ProgressState();

    await tester.pumpWidget(
      QuranApp(
        progressState: progressState,
      ),
    );

    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('Memorization'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    progressState.dispose();
  });
}
