// Person 3 — Widget test: searching for films, the tabs and the profile.
// Runs the whole app against the real API (see test/widget_test/README.md).
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/feed/feed_view.dart';
import 'package:shortreel/views/player/player_view.dart';
import 'package:shortreel/views/search/search_view.dart';
import 'package:shortreel/views/profile/edit_profile_view.dart';

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

    // The stub series have no cover, so the feed loads none of them; search
    // still finds one because it asks the catalog, not the feed.
    testWidgets('search finds a Series Jeen series the feed did not load', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Search');

      await tester.enterText(find.byType(TextField), 'storm');
      await waitFor(
        tester,
        find.descendant(
          of: find.byType(FilmCard),
          matching: find.text('Storm Heir'),
        ),
      );
      expect(find.text('Moon Bride'), findsNothing);
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

    testWidgets('a search with no match says so', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Search');

      await tester.enterText(find.byType(TextField), 'zzzz');
      await waitFor(tester, text('No films match your search.'));
      expect(find.byType(FilmCard), findsNothing);
      await closeApp(tester);
    });

    testWidgets('search offers Try again while the server is down', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await openTab(tester, 'Search');
      await serverDown(true);
      await tester.enterText(find.byType(TextField), 'paper');
      await waitFor(tester, text('Try again'));

      await serverDown(false);
      await tester.tap(text('Try again'));
      await waitFor(tester, find.byType(FilmCard));
      await closeApp(tester);
    });
  });

  group('tabs and profile', () {
    testWidgets('a viewer gets Home, Search, Catalog, Wallet and Profile', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');

      for (final tab in ['Home', 'Search', 'Catalog', 'Wallet', 'Profile']) {
        expect(navTab(tab), findsOneWidget, reason: tab);
      }
      expect(navTab('Admin'), findsNothing);
      await waitFor(tester, find.text(firstFilm));
      await closeApp(tester);
    });

    testWidgets('shows the seeded watchlist and unlocked films', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');

      await waitFor(tester, find.text('Demo Viewer'));
      await waitFor(tester, find.text('Salt & Signal'));
      await tester.tap(text('Unlocked'));
      await settle(tester);
      await waitFor(tester, find.text('Ember Protocol'));
      await closeApp(tester);
    });

    testWidgets('edits the profile through the API', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');

      await tester.tap(text('Edit profile'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('profile-name')), 'Vee');
      await tester.enterText(find.byKey(const Key('profile-bio')), 'Hello');
      await tester.tap(find.widgetWithText(FilledButton, th('Save')));
      await waitUntil(
        tester,
        () => find.byType(EditProfileView).evaluate().isEmpty,
        reason: 'the edit screen to close',
      );

      expect(find.text('Vee'), findsOneWidget);
      final me = await serverText('/auth/me', username: 'viewer01');
      expect(me, contains('"display_name":"Vee"'));
      expect(me, contains('"bio":"Hello"'));
      await closeApp(tester);
    });

    testWidgets('a profile with no name cannot be saved', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');
      await waitFor(tester, find.text('Demo Viewer'));
      await tester.tap(text('Edit profile'));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('profile-name')), '   ');
      await tester.pump();
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, th('Save')),
      );
      expect(save.onPressed, isNull);
      expect(
        await serverText('/auth/me', username: 'viewer01'),
        contains('"display_name":"Demo Viewer"'),
      );
      await closeApp(tester);
    });
  });
}
