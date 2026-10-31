import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/mock_repository.dart';
import 'package:shortreel/main.dart';
import 'package:shortreel/views/feed/unlock_success_view.dart';

const passwords = {
  'viewer01': '6666',
  'mira.lens': '4444',
  'admin': '1111',
  'kestrel_studio': '2222',
};

Future<void> logIn(WidgetTester tester, String username) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ShortReelApp(repository: MockRepository()));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login-username')), username);
  await tester.enterText(
    find.byKey(const Key('login-password')),
    passwords[username]!,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('viewer reports a film', (tester) async {
    await logIn(tester, 'viewer01');
    await tester.tap(find.text('Share').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Misleading AI label'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send report'));
    await tester.pumpAndSettle();
    expect(find.text('Report sent. Thank you.'), findsOneWidget);
  });

  testWidgets('viewer writes a comment', (tester) async {
    await logIn(tester, 'viewer01');
    await tester.tap(find.text('312'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('comment-input')),
      'Loved this one',
    );
    await tester.tap(find.byKey(const Key('comment-send')));
    await tester.pumpAndSettle();
    expect(find.text('Loved this one'), findsOneWidget);
  });

  testWidgets('guest is asked to log in before commenting', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShortReelApp(repository: MockRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch free episodes without an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('312'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comment-input')), findsNothing);
    expect(find.text('Log in to comment'), findsOneWidget);
  });

  testWidgets('a low balance goes straight to the top up sheet', (
    tester,
  ) async {
    await logIn(tester, 'kestrel_studio');
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eps').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('episode-5')));
    await tester.pumpAndSettle();
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(find.text('After unlock'), findsNothing);
  });

  testWidgets('buying and unlocking asks for confirmation', (tester) async {
    await logIn(tester, 'kestrel_studio');
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eps').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('episode-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('& unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm purchase'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(find.byType(UnlockSuccessView), findsOneWidget);
  });

  testWidgets('cancelling Plus shows the end date', (tester) async {
    await logIn(tester, 'mira.lens');
    await openTab(tester, 'Wallet');
    await tester.tap(find.text('Cancel Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel plan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ends'), findsOneWidget);
    expect(find.text('Cancel Plus'), findsNothing);
  });

  testWidgets('a rejected film is edited and resubmitted', (tester) async {
    await logIn(tester, 'mira.lens');
    await openTab(tester, 'Profile');
    await tester.tap(find.text('Creator studio'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit film').last);
    await tester.pumpAndSettle();
    expect(find.text('Rejected'), findsOneWidget);
    await tester.tap(find.text('Edit film').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('upload-prompt')),
      'Prompt: last tram',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Resubmit for review'));
    await tester.pumpAndSettle();
    expect(find.text('Rejected'), findsNothing);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('deleting a film asks first', (tester) async {
    await logIn(tester, 'mira.lens');
    await openTab(tester, 'Profile');
    await tester.tap(find.text('Creator studio'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete this film?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Night Tram'), findsNothing);
  });

  testWidgets('rejecting needs a reason', (tester) async {
    await logIn(tester, 'admin');
    await openTab(tester, 'Admin');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject').first);
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Reject');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('reason-input')),
      'Missing prompt credit',
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Review queue (1)'), findsOneWidget);
  });

  testWidgets('admin takes down a live film', (tester) async {
    await logIn(tester, 'admin');
    await openTab(tester, 'Admin');
    await tester.tap(find.text('Live (4)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Take down').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reason-input')),
      'Breaks the rules',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Take down'));
    await tester.pumpAndSettle();
    expect(find.text('Live (3)'), findsOneWidget);
  });

  testWidgets('admin takes down a reported film', (tester) async {
    await logIn(tester, 'admin');
    await openTab(tester, 'Admin');
    await tester.tap(find.text('Reports (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Take down film'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reason-input')),
      'Confirmed report',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Take down'));
    await tester.pumpAndSettle();
    expect(find.text('Reports (0)'), findsOneWidget);
  });
}
