// Person 3 — Widget test: searching for films.
// Runs the whole app against the real API (see test/widget_test/README.md).
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/feed/feed_view.dart';
import 'package:shortreel/views/player/player_view.dart';
import 'package:shortreel/views/search/search_view.dart';

import '../support/api_app_harness.dart';

void main() {
  useApiApp();

  group('search', () {
    testWidgets('the API search narrows the films; a result opens the player', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Search');

      await tester.enterText(find.byType(TextField), 'paper');
      await waitUntil(
        tester,
        () => find.byType(FilmCard).evaluate().length == 1,
        reason: 'one search result',
      );
      expect(
        find.descendant(
          of: find.byType(FilmCard),
          matching: find.text('Paper Moons'),
        ),
        findsWidgets,
      );

      await tester.tap(find.byType(FilmCard));
      await settle(tester);
      expect(find.byType(PlayerView), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('the search button on the feed opens the Search tab', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await tester.tap(
        find.descendant(
          of: find.byType(FeedView),
          matching: find.byIcon(Icons.search),
        ),
      );
      await settle(tester);
      expect(text('Discover'), findsOneWidget);
      await closeApp(tester);
    });
  });
}
