// Person 5 — Widget test: the Series Jeen catalog and player gestures.
// Runs the whole app against the real API (see test/widget_test/README.md).
// The backend's catalog routes run for real; only the outside provider is a
// stub in the test server.
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shortreel/views/player/player_view.dart';
import 'package:flutter/services.dart';

import '../support/api_app_harness.dart';

void main() {
  useApiApp();

  group('catalog', () {
    testWidgets('lists Series Jeen series through the API', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Catalog');
      await waitFor(tester, find.text('Storm Heir'));
      expect(find.text('Moon Bride'), findsWidgets);
      // The catalog is browsed, not searched: it has no search box.
      expect(find.byType(TextField), findsNothing);
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
  });

  group('player gestures', () {
    // The middle of the picture, clear of the buttons and the title.
    const middle = Offset(160, 360);

    testWidgets('a tap pauses the video and another resumes it', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');

      await tester.tapAt(middle);
      await waitUntil(tester, () => video.playing.isEmpty, reason: 'pause');
      await tester.tapAt(middle);
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');
      await closeApp(tester);
    });

    testWidgets('a double tap likes the film on the server', (tester) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));

      await tester.tapAt(middle);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(middle);
      await settle(tester);

      expect(await serverText('/films/5'), contains('"like_count":1'));
      await closeApp(tester);
    });

    testWidgets('holding the right edge plays at 2x until let go', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');

      // The 2x zone is the right third, left of the buttons.
      final hold = await tester.startGesture(const Offset(290, 360));
      await tester.pump(const Duration(milliseconds: 700));
      await waitUntil(tester, () => video.speeds.contains(2.0), reason: '2x');
      await hold.up();
      await waitUntil(tester, () => video.speeds.last == 1.0, reason: '1x');
      await closeApp(tester);
    });

    testWidgets('turning haptics off stops the buzz when holding for 2x', (
      tester,
    ) async {
      var buzzes = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') buzzes++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      Future<void> holdForTwoX() async {
        final hold = await tester.startGesture(const Offset(290, 360));
        await tester.pump(const Duration(milliseconds: 700));
        await hold.up();
        await settle(tester);
      }

      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await holdForTwoX();
      expect(buzzes, 1);

      await openTab(tester, 'Profile');
      await tester.tap(find.byTooltip(th('Settings')).first);
      await settle(tester);
      await tester.tap(find.byKey(const Key('settings-haptics')));
      await tester.pump();
      await tester.pageBack();
      await settle(tester);
      await openTab(tester, 'Home');
      await holdForTwoX();
      expect(buzzes, 1);
      await closeApp(tester);
    });
  });
}
