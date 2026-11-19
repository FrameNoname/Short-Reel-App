// Person 5 — Widget test: the Series Jeen catalog.
// Runs the whole app against the real API (see test/widget_test/README.md).
// The backend's catalog routes run for real; only the outside provider is a
// stub in the test server.
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shortreel/views/player/player_view.dart';

import '../support/api_app_harness.dart';

void main() {
  useApiApp();

  group('catalog', () {
    testWidgets('lists Series Jeen series through the API and searches', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Catalog');
      await waitFor(tester, find.text('Storm Heir'));
      expect(find.text('Moon Bride'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'storm');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await waitUntil(
        tester,
        () => find.text('Moon Bride').evaluate().isEmpty,
        reason: 'the search to drop Moon Bride',
      );
      expect(find.text('Storm Heir'), findsWidgets);
      await closeApp(tester);
    });

    testWidgets('a series opens in the player and plays the API stream', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Catalog');
      await waitFor(tester, find.text('Storm Heir'));

      await tester.tap(find.text('Storm Heir').first);
      await waitFor(tester, find.byType(PlayerView));
      await waitUntil(
        tester,
        () => video.urls.any((u) => u.contains('/stub/1.m3u8')),
        reason: 'episode 1 to load from the API',
      );
      await waitUntil(tester, () => video.playing.isNotEmpty, reason: 'play');
      await closeApp(tester);
    });

    testWidgets('a paid series episode is unlocked for 10 coins', (
      tester,
    ) async {
      await logIn(tester, 'viewer01', allowTestFontOverflow: true);
      await openTab(tester, 'Catalog');
      await waitFor(tester, find.text('Storm Heir'));
      await tester.tap(find.text('Storm Heir').first);
      await waitFor(tester, find.byType(PlayerView));

      // Series Jeen gives 5 free episodes; the 6th costs 10 coins.
      await tester.tap(find.byIcon(Icons.playlist_play_rounded).first);
      await waitFor(tester, find.byKey(const Key('episode-6')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('episode-6')));
      await settle(tester);
      await tester.tap(text('Unlock for 10 coins'));
      await waitFor(tester, text('Episode 6 is yours'));

      expect(
        await serverText('/wallet', username: 'viewer01'),
        contains('"coin_balance":70'),
      );
      await closeApp(tester);
    });

    testWidgets('the catalog offers Try again while the server is down', (
      tester,
    ) async {
      // The catalog loads as soon as the app opens, so the server is down
      // from the start.
      await serverDown(true);
      await enterAsGuest(tester);
      await openTab(tester, 'Catalog');
      await waitFor(tester, text('Try again'));

      await serverDown(false);
      await tester.tap(text('Try again'));
      await waitFor(tester, find.text('Storm Heir'));
      await closeApp(tester);
    });

    testWidgets('a search while the server is down offers Try again', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Catalog');
      await waitFor(tester, find.text('Moon Bride'));

      await serverDown(true);
      await tester.enterText(find.byType(TextField), 'storm');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await waitFor(tester, text('Try again'));
      // The old, unfiltered list is gone rather than passed off as results.
      expect(find.text('Moon Bride'), findsNothing);

      // Try again repeats the same search.
      await serverDown(false);
      await tester.tap(text('Try again'));
      await waitFor(tester, find.text('Storm Heir'));
      expect(find.text('Moon Bride'), findsNothing);
      await closeApp(tester);
    });
  });
}
