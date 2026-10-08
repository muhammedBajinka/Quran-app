import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/media_social_repository.dart';
import 'package:quran_app/models/media/media_report_reason.dart';
import 'package:quran_app/models/media/media_feed_navigation.dart';
import 'package:quran_app/widgets/media_creator_identity.dart';
import 'package:quran_app/widgets/media_swipe_surface.dart';

void main() {
  test('swiping follows the visible tabs and creator comes after For You', () {
    expect(MediaFeedTab.other.previous, isNull);
    expect(MediaFeedTab.dua.next, MediaFeedTab.recitation);
    expect(MediaFeedTab.recitation.previous, MediaFeedTab.dua);
    expect(MediaFeedTab.forYou.previous, MediaFeedTab.following);
    expect(MediaFeedTab.forYou.next, isNull);
  });
  test('all visible report choices produce accepted database codes', () {
    const accepted = {'inappropriate', 'misleading', 'harassment', 'spam', 'copyright', 'other'};
    for (final reason in MediaReportReason.values) {
      expect(accepted, contains(reason.code));
      expect(MediaReportReason.parse(reason.label), reason);
      expect(MediaReportReason.parse(reason.code), reason);
    }
    expect(() => MediaReportReason.parse('invalid'), throwsArgumentError);
  });

  testWidgets('chosen handle and verified badge appear together and open creator', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaCreatorIdentity(
      creator: const CreatorProfile(userId: 'creator', username: 'chosen_handle', displayName: 'Different Name', isSuspended: false, isVerified: true),
      fallbackName: 'Fallback', onPressed: () => opened = true,
    ))));
    expect(find.text('@chosen_handle'), findsOneWidget);
    expect(find.text('@Different Name'), findsNothing);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    await tester.tap(find.text('@chosen_handle'));
    expect(opened, isTrue);
  });

  testWidgets('unverified creator has no badge', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MediaCreatorIdentity(
      creator: CreatorProfile(userId: 'creator', username: 'normal', isSuspended: false, isVerified: false), fallbackName: 'Fallback',
    ))));
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets('horizontal swipes fire once and vertical swipes keep paging', (tester) async {
    var left = 0; var right = 0; var page = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaSwipeSurface(
      onSwipeLeft: () => left++, onSwipeRight: () => right++,
      child: PageView(scrollDirection: Axis.vertical, onPageChanged: (index) => page = index,
        children: const [ColoredBox(color: Colors.black), ColoredBox(color: Colors.green)]),
    ))));
    await tester.drag(find.byType(PageView), const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(left, 1); expect(right, 0); expect(page, 0);
    await tester.drag(find.byType(PageView), const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(right, 1);
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(page, 1); expect(left, 1); expect(right, 1);
  });

  testWidgets('seeking a child slider does not switch feed categories', (tester) async {
    var swipes = 0; var value = 0.5;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, setState) => MediaSwipeSurface(
      onSwipeLeft: () => swipes++, onSwipeRight: () => swipes++,
      child: Center(child: Slider(value: value, onChanged: (next) => setState(() => value = next))),
    )))));
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(value, greaterThan(0.5)); expect(swipes, 0);
  });
}
