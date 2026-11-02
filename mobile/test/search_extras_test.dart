import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/film_search_controller.dart';
import 'support/mock_repository.dart';

import 'app_shell_test.dart' show enterAsGuest, openTab;

Future<void> focusSearch(WidgetTester tester) async {
  await tester.tap(find.byType(TextField).first);
  await tester.pumpAndSettle();
}

void main() {
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

    test('trending lists the most liked films first', () async {
      await search.loadTrending();
      final likes = search.trending.map((f) => f.likeCount).toList();
      expect(likes, isNotEmpty);
      expect(likes.length, lessThanOrEqualTo(5));
      expect(likes, [...likes]..sort((a, b) => b.compareTo(a)));
    });
  });

  group('search screen', () {
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
