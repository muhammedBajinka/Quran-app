import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/account_deletion_repository.dart';
import 'package:quran_app/screens/account/account_deletion_screen.dart';

class FakeDeletionStore implements AccountDeletionStore {
  bool pending = false;
  bool failLoad = false;
  bool failWrite = false;
  int submissions = 0;
  @override
  Future<bool> hasPendingRequest() async {
    if (failLoad) throw StateError('offline');
    return pending;
  }
  @override
  Future<void> requestDeletion() async {
    submissions++;
    if (failWrite) throw StateError('offline');
    pending = true;
  }
  @override
  Future<void> cancelRequest() async { pending = false; }
}

void main() {
  Future<void> open(WidgetTester tester, FakeDeletionStore store) async {
    await tester.pumpWidget(MaterialApp(home: AccountDeletionScreen(repository: store)));
    await tester.pumpAndSettle();
  }
  testWidgets('confirmation records a pending request and cancellation reverses it', (tester) async {
    final store = FakeDeletionStore();
    await open(tester, store);
    await tester.tap(find.text('Request account deletion'));
    await tester.pumpAndSettle();
    expect(store.submissions, 0);
    await tester.tap(find.text('Keep account'));
    await tester.pumpAndSettle();
    expect(store.submissions, 0);
    await tester.tap(find.text('Request account deletion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();
    expect(store.submissions, 1);
    expect(find.text('Deletion request pending'), findsOneWidget);
    expect(find.text('Deletion request submitted. Your account has not been deleted.'), findsOneWidget);
    await tester.tap(find.text('Cancel deletion request'));
    await tester.pumpAndSettle();
    expect(store.pending, isFalse);
    expect(find.text('No pending deletion request'), findsOneWidget);
  });
  testWidgets('failed submission does not claim pending or removed', (tester) async {
    final store = FakeDeletionStore()..failWrite = true;
    await open(tester, store);
    await tester.tap(find.text('Request account deletion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();
    expect(find.text('No pending deletion request'), findsOneWidget);
    expect(find.text('Deletion request pending'), findsNothing);
  });
  testWidgets('unknown status blocks submission and supports retry', (tester) async {
    final store = FakeDeletionStore()..failLoad = true;
    await open(tester, store);
    expect(find.text('Could not load your request status.'), findsOneWidget);
    expect(find.text('Request account deletion'), findsNothing);
    store.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Request account deletion'), findsOneWidget);
  });
}
