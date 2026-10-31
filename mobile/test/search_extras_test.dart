import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/film_search_controller.dart';
import 'package:shortreel/data/mock_repository.dart';

import 'app_shell_test.dart' show enterAsGuest, logIn, openTab;

Future<void> focusSearch(WidgetTester tester) async {
  await tester.tap(find.byType(TextField).first);
  await tester.pumpAndSettle();
}

void main() {
  group('continue watching (repository)', () {
    test('episodes someone unlocked count as progress', () {
      final repo = MockRepository();
      final items = repo.continueWatching(6);
      expect(items, isNotEmpty);
      expect(items.first.film.title, 'Ember Protocol');
      expect(items.first.episodeNo, 3);
      expect(items.first.fraction, closeTo(3 / 8, 0.001));
    });

    test('the film watched last comes first and keeps its newest episode', () {
      final repo = MockRepository();
      repo.recordProgress(6, 1, 2);
      repo.recordProgress(6, 3, 5);
      repo.recordProgress(6, 1, 4);
      final items = repo.continueWatching(6);
      expect(items.map((i) => i.film.id).take(2), [1, 3]);
      expect(items.first.episodeNo, 4);
      expect(items.where((i) => i.film.id == 3).single.episodeNo, 5);
    });

    test('a finished film drops off the list', () {
      final repo = MockRepository();
      repo.recordProgress(6, 1, 8);
      expect(repo.continueWatching(6).any((i) => i.film.id == 1), isFalse);
    });

    test('someone who watched nothing has nothing to continue', () {
      expect(MockRepository().continueWatching(5), isEmpty);
    });
  });

  group('recent and trending searches (controller)', () {
    late FilmSearchController search;
    setUp(() => search = FilmSearchController(MockRepository()));

    test('the latest search goes first and repeats are merged', () {
      search.remember('moon');
      search.remember('lighthouse');
      search.remember('MOON');
      expect(search.recent, ['MOON', 'lighthouse']);
    });

    test('blank searches are not kept', () {
      search.remember('   ');
      expect(search.recent, isEmpty);
    });

    test('only the latest eight are kept', () {
      for (var i = 1; i <= 10; i++) {
        search.remember('term $i');
      }
      expect(search.recent.length, 8);
      expect(search.recent.first, 'term 10');
      expect(search.recent.last, 'term 3');
    });

    test('a search can be forgotten or all cleared', () {
      search.remember('a');
      search.remember('b');
      search.forget('a');
      expect(search.recent, ['b']);
      search.clearRecent();
      expect(search.recent, isEmpty);
    });

    test('trending lists the most watched films first', () async {
      await search.loadTrending();
      final views = search.trending.map((f) => f.viewCount).toList();
      expect(views, isNotEmpty);
      expect(views.length, lessThanOrEqualTo(5));
      expect(views, [...views]..sort((a, b) => b.compareTo(a)));
    });
  });

  group('search screen', () {
    testWidgets('a viewer sees where they left off', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Search');
      expect(find.text('Continue watching'), findsOneWidget);
      expect(find.text('Episode 3'), findsOneWidget);
    });

    testWidgets('tapping a card resumes at that episode', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Search');
      await tester.tap(find.byKey(const Key('continue-3')));
      await tester.pumpAndSettle();
      expect(find.textContaining('EP 3'), findsOneWidget);
    });

    testWidgets('a guest has nothing to continue', (tester) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      expect(find.text('Continue watching'), findsNothing);
    });

    testWidgets('playing an episode adds the film to the row', (tester) async {
      await logIn(tester, 'viewer01');
      await tester.tap(find.text('Eps'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('episode-2')));
      await tester.pumpAndSettle();

      await openTab(tester, 'Search');
      expect(find.text('Episode 2'), findsOneWidget);
    });

    testWidgets('searching hides the row', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Search');
      await tester.enterText(find.byType(TextField).first, 'moon');
      await tester.pumpAndSettle();
      expect(find.text('Continue watching'), findsNothing);
    });

    testWidgets('focusing the empty box shows what is trending', (
      tester,
    ) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await focusSearch(tester);

      expect(find.text('Trending'), findsOneWidget);
      expect(find.byKey(const Key('trending-1')), findsOneWidget);
      expect(find.text('Recent searches'), findsNothing);
    });

    testWidgets('picking a trending film searches for it and remembers it', (
      tester,
    ) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await focusSearch(tester);
      await tester.tap(find.byKey(const Key('trending-1')));
      await tester.pumpAndSettle();

      expect(find.text('1 film'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await focusSearch(tester);
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.byKey(const Key('recent-Salt & Signal')), findsOneWidget);
    });

    testWidgets('submitting a search remembers it', (tester) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await focusSearch(tester);
      await tester.enterText(find.byType(TextField).first, 'moon');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await focusSearch(tester);
      expect(find.byKey(const Key('recent-moon')), findsOneWidget);
    });

    testWidgets('a recent search can be removed or all cleared', (
      tester,
    ) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await focusSearch(tester);
      await tester.enterText(find.byType(TextField).first, 'moon');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await focusSearch(tester);

      await tester.tap(find.byKey(const Key('recent-remove-moon')));
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsNothing);
    });

    testWidgets('Clear all empties the recent searches', (tester) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await focusSearch(tester);
      await tester.enterText(find.byType(TextField).first, 'moon');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await focusSearch(tester);

      await tester.tap(find.byKey(const Key('recent-clear')));
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsNothing);
      expect(find.text('Trending'), findsOneWidget);
    });

    testWidgets('a tap outside the field keeps the suggestions open', (
      tester,
    ) async {
      // On the web a tap outside a text field normally takes focus away,
      // which would hide a suggestion before its tap lands.
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await focusSearch(tester);

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.onTapOutside, isNotNull);
      field.onTapOutside!(const PointerDownEvent());
      await tester.pumpAndSettle();
      expect(find.text('Trending'), findsOneWidget);
    });

    testWidgets('tapping empty space under the suggestions closes them', (
      tester,
    ) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await focusSearch(tester);
      expect(find.text('Trending'), findsOneWidget);

      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();
      expect(find.text('Trending'), findsNothing);
      expect(find.text('4 films'), findsOneWidget);
    });
  });
}
