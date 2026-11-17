// Widget tests of the full app against the real API.
//
// The app runs as in main(): ApiRepository and ApiClient send real HTTP to the
// backend, which reads and writes a real MariaDB database. Only the video
// decoder (no platform in tests) and the outside Series Jeen provider (to
// spare its quota) are stand-ins. Every test starts from the seed data.
//
// Start the test API first; it builds its own shortreel_widget_test database:
//   node backend/scripts/widget-test-server.js
// then, in mobile/:
//   flutter test test/app_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/admin/admin_settings_view.dart';
import 'package:shortreel/views/app_shell.dart';
import 'package:shortreel/views/auth/login_view.dart';
import 'package:shortreel/views/feed/feed_view.dart';
import 'package:shortreel/views/feed/rail_icons.dart';
import 'package:shortreel/views/player/player_view.dart';
import 'package:shortreel/views/profile/edit_profile_view.dart';
import 'package:shortreel/views/profile/settings_view.dart';
import 'package:shortreel/views/search/search_view.dart';
import 'package:shortreel/views/wallet/top_up_view.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/api_app_harness.dart';

/// The first film of the seeded feed (the newest).
const firstFilm = 'ShortReel Intro';

void main() {
  ApiTestBinding.ensureInitialized();

  late FakeVideoPlatform video;

  setUp(() async {
    await resetServer();
    video = FakeVideoPlatform();
    VideoPlayerPlatform.instance = video;
  });

  Future<String> server(String path, {String? username}) async =>
      jsonEncode(await serverGet(path, username: username));

  group('signing in', () {
    testWidgets('the app opens on the login screen', (tester) async {
      await pumpApp(tester);

      expect(find.byType(LoginView), findsOneWidget);
      expect(text('Create account'), findsOneWidget);
      expect(text('Watch free episodes without an account'), findsOneWidget);
    });

    testWidgets('a wrong password is refused by the API', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byKey(const Key('login-username')),
        'viewer01',
      );
      await tester.enterText(find.byKey(const Key('login-password')), 'nope');
      await tester.tap(find.widgetWithText(FilledButton, th('Log in')));
      await waitFor(tester, find.text('Username or password is wrong'));

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

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

    testWidgets('the admin gets the Admin tab and no Wallet', (tester) async {
      await logIn(tester, 'admin');

      expect(navTab('Admin'), findsOneWidget);
      expect(navTab('Wallet'), findsNothing);
      await waitFor(tester, find.text(firstFilm));
      await closeApp(tester);
    });

    testWidgets('a guest watches the feed; the wallet asks them to log in', (
      tester,
    ) async {
      await enterAsGuest(tester);
      await waitFor(tester, find.text(firstFilm));

      await openTab(tester, 'Wallet');
      await tester.tap(find.widgetWithText(FilledButton, th('Log in')));
      await settle(tester);
      expect(find.byType(LoginView), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('creating an account', () {
    Future<void> register(
      WidgetTester tester,
      String username,
      String password, {
      String? confirm,
    }) async {
      await pumpApp(tester);
      await tester.tap(text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('register-username')),
        username,
      );
      await tester.enterText(
        find.byKey(const Key('register-password')),
        password,
      );
      await tester.enterText(
        find.byKey(const Key('register-confirm')),
        confirm ?? password,
      );
      final submit = find.widgetWithText(FilledButton, th('Create account'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await settle(tester);
    }

    testWidgets('a weak password never reaches the API', (tester) async {
      await register(tester, 'newbie', 'short', confirm: 'other');

      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(LoginView), findsNothing, reason: 'still registering');
      expect(await serverLogIn('newbie', 'short'), isFalse);
    });

    testWidgets('a new account is created and signed in', (tester) async {
      await register(tester, 'newbie', 'abc12345');
      await waitFor(tester, find.byType(AppShell));

      await openTab(tester, 'Profile');
      await waitFor(tester, find.text('newbie'));
      await closeApp(tester);
    });

    testWidgets('a taken username is refused by the API', (tester) async {
      await register(tester, 'viewer01', 'abc12345');
      await waitFor(tester, find.text('Username is already taken'));

      expect(find.byType(AppShell), findsNothing);
    });
  });

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

      expect(await server('/films/5'), contains('"like_count":1'));
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

      expect(await server('/films/5/comments'), contains('Great montage'));
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

  group('episodes and unlocking', () {
    Future<void> openEpisode(WidgetTester tester, int no) async {
      await waitFor(tester, find.text(firstFilm));
      await tester.tap(find.byIcon(Icons.playlist_play_rounded).first);
      await waitFor(tester, find.byKey(Key('episode-$no')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('episode-$no')));
      await settle(tester);
    }

    testWidgets('the sheet shows the API episodes, free and paid', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await tester.tap(find.byIcon(Icons.playlist_play_rounded).first);
      await waitFor(tester, find.byKey(const Key('episode-8')));

      expect(text('8 episodes'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('episode-3')),
          matching: text('20 coins'),
        ),
        findsOneWidget,
      );
      await closeApp(tester);
    });

    testWidgets('a viewer spends 20 coins on episode 3', (tester) async {
      await logIn(tester, 'viewer01', allowTestFontOverflow: true);
      await openEpisode(tester, 3);

      await tester.tap(text('Unlock for 20 coins'));
      await waitFor(tester, text('Episode 3 is yours'));

      expect(
        await server('/wallet', username: 'viewer01'),
        contains('"coin_balance":60'),
      );
      await tester.tap(text('Play episode 3'));
      await settle(tester);
      await waitUntil(tester, () => video.playing.length == 1, reason: 'play');
      await closeApp(tester);
    });

    testWidgets('a new account with no coins buys a pack, then unlocks', (
      tester,
    ) async {
      await pumpApp(tester, allowTestFontOverflow: true);
      await tester.tap(text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('register-username')), 'pat');
      await tester.enterText(
        find.byKey(const Key('register-password')),
        'abc12345',
      );
      await tester.enterText(
        find.byKey(const Key('register-confirm')),
        'abc12345',
      );
      final submit = find.widgetWithText(FilledButton, th('Create account'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await waitFor(tester, find.byType(AppShell));
      await openEpisode(tester, 3);

      expect(text('Not enough coins'), findsOneWidget);
      await tester.tap(text(r'Buy 330 coins · $4.99 & unlock'));
      await settle(tester);
      await tester.tap(text('Confirm'));
      await waitFor(tester, text('Episode 3 is yours'));

      // 330 bought, 20 spent.
      await tester.tap(text('Play episode 3'));
      await settle(tester);
      await openTab(tester, 'Wallet');
      await waitFor(tester, find.text('310'));
      await closeApp(tester);
    });

    testWidgets('a guest on a paid episode is asked to log in', (tester) async {
      await enterAsGuest(tester);
      await openEpisode(tester, 3);

      expect(text('Log in to keep watching'), findsOneWidget);
      await tester.tap(text('Keep browsing free episodes'));
      await settle(tester);
      expect(text('Log in to keep watching'), findsNothing);
      await closeApp(tester);
    });
  });

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
  });

  group('wallet', () {
    testWidgets('shows the balance and adds the free demo coins', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Wallet');
      await waitFor(tester, find.text('80'));

      await tester.tap(text('+100 free'));
      await waitFor(tester, find.text('180'));
      expect(
        await server('/wallet', username: 'viewer01'),
        contains('"coin_balance":180'),
      );
      await closeApp(tester);
    });

    testWidgets('a coin pack is bought from the top-up screen', (tester) async {
      await logIn(tester, 'viewer01', allowTestFontOverflow: true);
      await openTab(tester, 'Wallet');

      await tester.tap(find.widgetWithText(FilledButton, th('Top up coins')));
      await waitFor(tester, text('60 coins'));
      await tester.tap(text('60 coins'));
      await tester.pumpAndSettle();
      await tester.tap(text(r'Buy 60 coins for $0.99'));
      await waitUntil(
        tester,
        () => find.byType(TopUpView).evaluate().isEmpty,
        reason: 'the top-up screen to close',
      );

      await waitFor(tester, find.text('140'));
      expect(
        await server('/wallet/transactions', username: 'viewer01'),
        contains('0.99'),
      );
      await closeApp(tester);
    });
  });

  group('profile and settings', () {
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
      final me = await server('/auth/me', username: 'viewer01');
      expect(me, contains('"display_name":"Vee"'));
      expect(me, contains('"bio":"Hello"'));
      await closeApp(tester);
    });

    testWidgets('logging out from settings asks first, then shows login', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');
      await tester.tap(find.byTooltip(th('Settings')).first);
      await settle(tester);
      expect(find.byType(SettingsView), findsOneWidget);

      final logout = find.byKey(const Key('settings-logout'));
      await tester.ensureVisible(logout);
      await tester.pumpAndSettle();
      await tester.tap(logout);
      await settle(tester);
      await tester.tap(text('Stay'));
      await settle(tester);
      expect(find.byType(SettingsView), findsOneWidget);

      await tester.tap(logout);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, th('Log out')));
      await waitFor(tester, find.byType(LoginView));
      expect(find.byType(AppShell), findsNothing);
      await closeApp(tester);
    });
  });

  group('admin', () {
    Future<void> openAdmin(WidgetTester tester) async {
      await logIn(tester, 'admin');
      await openTab(tester, 'Admin');
    }

    testWidgets('the dashboard shows the seeded sales', (tester) async {
      await openAdmin(tester);

      await waitFor(tester, find.text(r'$0.99'));
      expect(text('80 coins'), findsWidgets);
      expect(find.text('Salt & Signal'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('takes a film down and the feed drops it', (tester) async {
      await openAdmin(tester);
      await tester.tap(text('Films and episodes'));
      await waitFor(tester, find.text('Glass Harbour'));

      final row = find.ancestor(
        of: find.text('Glass Harbour'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: row.first, matching: find.byType(Switch)),
      );
      await settle(tester);
      await tester.tap(text('Take down'));
      await waitFor(tester, text('Film taken down.'));

      expect(await server('/films'), isNot(contains('Glass Harbour')));
      await closeApp(tester);
    });

    testWidgets('deletes a comment', (tester) async {
      await openAdmin(tester);
      await tester.tap(text('Comments'));
      await waitFor(tester, find.text('Love the paper-cut style.'));

      final card = find.ancestor(
        of: find.text('Love the paper-cut style.'),
        matching: find.byType(Row),
      );
      await tester.tap(
        find.descendant(of: card.first, matching: find.byTooltip('Delete')),
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, th('Delete')));
      await waitFor(tester, text('Comment deleted.'));

      expect(
        await server('/films/2/comments'),
        isNot(contains('Love the paper-cut style.')),
      );
      await closeApp(tester);
    });

    testWidgets('opens prices and coin packs and saves them', (tester) async {
      await openAdmin(tester);
      await tester.tap(text('Prices and coin packs'));
      await waitFor(tester, find.byType(AdminSettingsView));
      await waitFor(tester, find.text('Popular'));

      final save = text('Save changes');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await waitFor(tester, text('Changes saved.'));
      await closeApp(tester);
    });
  });
}
