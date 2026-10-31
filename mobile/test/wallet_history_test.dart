import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_shell_test.dart' show logIn, openTab;

Future<void> openWallet(WidgetTester tester) async {
  await logIn(tester, 'viewer01');
  await openTab(tester, 'Wallet');
}

void main() {
  testWidgets('the history starts on All with both kinds of activity', (
    tester,
  ) async {
    await openWallet(tester);
    expect(find.text('Ember Protocol, Episode 3'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Demo top-up'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Demo top-up'), findsOneWidget);
    expect(find.text('Episode unlock'), findsOneWidget);
    expect(find.text('Top-up'), findsOneWidget);
  });

  testWidgets('Spent shows only unlocks and their total', (tester) async {
    await openWallet(tester);
    await tester.tap(find.byKey(const Key('history-spent')));
    await tester.pumpAndSettle();

    expect(find.text('Ember Protocol, Episode 3'), findsOneWidget);
    expect(find.text('Demo top-up'), findsNothing);
    expect(find.textContaining('Spent', findRichText: true), findsWidgets);
    expect(find.textContaining('−20', findRichText: true), findsWidgets);
  });

  testWidgets('Added shows only top-ups and their total', (tester) async {
    await openWallet(tester);
    await tester.tap(find.byKey(const Key('history-added')));
    await tester.pumpAndSettle();

    expect(find.text('Demo top-up'), findsOneWidget);
    expect(find.text('Ember Protocol, Episode 3'), findsNothing);
    expect(find.textContaining('+100', findRichText: true), findsWidgets);
  });

  testWidgets('a top-up made now is listed under Today', (tester) async {
    await openWallet(tester);
    await tester.tap(find.text('+100 free'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('a filter with nothing in it explains why', (tester) async {
    await logIn(tester, 'admin');
    await openTab(tester, 'Wallet');
    expect(find.text('No coin activity yet.'), findsOneWidget);

    await tester.tap(find.text('+100 free'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-spent')));
    await tester.pumpAndSettle();
    expect(find.text('No unlocks yet.'), findsOneWidget);
  });

  testWidgets('hiding the history also hides the filters', (tester) async {
    await openWallet(tester);
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-all')), findsNothing);
    expect(find.text('Demo top-up'), findsNothing);
  });
}
