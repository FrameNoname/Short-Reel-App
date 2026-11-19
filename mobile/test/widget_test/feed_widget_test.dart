// Person 2 — Widget test: the feed, its player, swiping and the next episode.
// Runs the whole app against the real API (see test/widget_test/README.md).
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/auth/login_view.dart';
import 'package:shortreel/views/feed/rail_icons.dart';

import '../support/api_app_harness.dart';

void main() {
  useApiApp();

  group('feed', () {
    testWidgets('plays the stream the API hands out, pausing it off screen', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');

      expect(video.live, 1);
      expect(video.urls.single, contains('/api/episodes/'));

      await openTab(tester, 'Wallet');
      expect(video.playing, isEmpty);
      await openTab(tester, 'Home');
      expect(video.playing, hasLength(1));
      await closeApp(tester);
    });

    testWidgets('a guest who taps like is sent to log in', (tester) async {
      await enterAsGuest(tester);
      await waitFor(tester, find.text(firstFilm));

      await tester.tap(find.byIcon(Icons.favorite_rounded).first);
      await settle(tester);
      expect(find.byType(LoginView), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('like and save are stored on the server', (tester) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));

      await tester.tap(find.byIcon(Icons.favorite_rounded).first);
      await tester.tap(find.byIcon(Icons.bookmark_rounded).first);
      await settle(tester);

      expect(await serverText('/films/5'), contains('"like_count":1'));
      final saved = await serverGet('/watchlist', username: 'viewer01');
      expect(saved['film_ids'], contains(5));
      await closeApp(tester);
    });

    testWidgets('a comment is posted and read back from the API', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));

      await tester.tap(find.byType(CommentIcon).first);
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('comment-input')),
        'Great montage',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('comment-send')));
      // The box empties once the API took the comment, and the list shows it.
      await waitFor(
        tester,
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Great montage'),
        ),
      );

      expect(await serverText('/films/5/comments'), contains('Great montage'));
      await closeApp(tester);
    });

    testWidgets('the speed sheet changes how fast the video plays', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');

      await tester.tap(find.byIcon(Icons.speed_rounded).first);
      await settle(tester);
      await tester.tap(find.text('2x'));
      await settle(tester);

      expect(text('2x speed'), findsOneWidget);
      expect(video.speeds.last, 2.0);
      await closeApp(tester);
    });
  });

  group('moving through films', () {
    testWidgets('a swipe up moves to the next film', (tester) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');

      await tester.fling(find.text(firstFilm), const Offset(0, -500), 1500);
      await waitFor(tester, find.text('Glass Harbour'));
      await waitUntil(
        tester,
        () => video.playing.length == 1 && video.created >= 2,
        reason: 'the next film to play',
      );
      await closeApp(tester);
    });

    testWidgets('the next episode plays when one ends', (tester) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');

      final episodes = (await serverGet('/films/5'))['episodes'] as List;
      final second = episodes.firstWhere((e) => e['episode_no'] == 2);

      video.finish(video.playing.single);
      await waitUntil(
        tester,
        () => video.urls.last.contains('/episodes/${second['id']}/'),
        reason: 'episode 2 to load',
      );
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');
      await closeApp(tester);
    });

    testWidgets('the feed offers Try again while the server is down', (
      tester,
    ) async {
      await serverDown(true);
      await enterAsGuest(tester);
      await waitFor(tester, text('Try again'));
      expect(find.text(firstFilm), findsNothing);

      await serverDown(false);
      await tester.tap(text('Try again'));
      await waitFor(tester, find.text(firstFilm));
      await closeApp(tester);
    });
  });
}
