import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/models/audio/media_item.dart';
import 'package:quran_app/data/media_social_repository.dart';
import 'package:quran_app/widgets/media_search_results.dart';

void main() {
  testWidgets('shows three previews per row and opens the tapped result', (
    tester,
  ) async {
    int? opened;
    final items = List.generate(
      6,
      (index) => MediaItem(
        id: '$index',
        type: MediaItemType.other,
        title: 'Post $index',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaSearchResults(
            items: items,
            creators: const [],
            onOpenMedia: (index) => opened = index,
            onOpenCreator: (_) {},
          ),
        ),
      ),
    );
    final first = tester.getTopLeft(find.text('Post 0'));
    final third = tester.getTopLeft(find.text('Post 2'));
    final fourth = tester.getTopLeft(find.text('Post 3'));
    expect(first.dy, third.dy);
    expect(fourth.dy, greaterThan(first.dy));
    expect(opened, isNull);
    await tester.tap(find.text('Post 2'));
    expect(opened, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('creator-only results open the selected profile', (tester) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaSearchResults(
            items: const [],
            creators: const [
              CreatorProfile(
                userId: 'creator',
                displayName: 'Public name',
                username: 'handle',
                isSuspended: false,
                isVerified: false,
              ),
            ],
            onOpenMedia: (_) {},
            onOpenCreator: (id) => opened = id,
          ),
        ),
      ),
    );
    expect(find.text('@handle'), findsOneWidget);
    await tester.tap(find.text('Public name'));
    expect(opened, 'creator');
    expect(find.text('No posts or creators found.'), findsNothing);
  });
  testWidgets('empty search has an explicit message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaSearchResults(
            items: const [],
            creators: const [],
            onOpenMedia: (_) {},
            onOpenCreator: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('No posts or creators found.'), findsOneWidget);
  });
}
