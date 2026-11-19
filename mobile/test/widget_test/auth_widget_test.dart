// Person 1 — Widget test: signing in, creating an account, profile and settings.
// Runs the whole app against the real API (see test/widget_test/README.md).
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/app_shell.dart';
import 'package:shortreel/views/auth/login_view.dart';
import 'package:shortreel/views/profile/edit_profile_view.dart';
import 'package:shortreel/views/profile/settings_view.dart';
import 'package:shortreel/views/search/search_view.dart';

import '../support/api_app_harness.dart';

void main() {
  useApiApp();

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
  });

  group('creating an account', () {
    testWidgets('a weak password never reaches the API', (tester) async {
      await register(tester, 'newbie', 'short', confirm: 'other');

      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(LoginView), findsNothing, reason: 'still registering');
      expect(await serverLogIn('newbie', 'short'), isFalse);
    });

    testWidgets('passwords that do not match never reach the API', (
      tester,
    ) async {
      await register(tester, 'newbie', 'abc12345', confirm: 'abc12346');

      expect(text("Passwords don't match."), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(await serverLogIn('newbie', 'abc12345'), isFalse);
    });

    testWidgets('a new account is created and signed in', (tester) async {
      await register(tester, 'newbie', 'abc12345');
      await waitFor(tester, find.byType(AppShell));

      await openTab(tester, 'Profile');
      await waitFor(tester, find.text('newbie'));
      expect(await serverLogIn('newbie', 'abc12345'), isTrue);
      await closeApp(tester);
    });

    testWidgets('a taken username is refused by the API', (tester) async {
      await register(tester, 'viewer01', 'abc12345');
      await waitFor(tester, find.text('Username is already taken'));

      expect(find.byType(AppShell), findsNothing);
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
      final me = await serverText('/auth/me', username: 'viewer01');
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

    testWidgets('the default speed in settings is used by the next film', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');
      await tester.tap(find.byTooltip(th('Settings')).first);
      await settle(tester);

      await tester.tap(find.text('1.5x'));
      await tester.pump();
      await tester.pageBack();
      await settle(tester);
      await openTab(tester, 'Search');
      await tester.enterText(find.byType(TextField), 'paper');
      await waitUntil(
        tester,
        () => find.byType(FilmCard).evaluate().length == 1,
        reason: 'one search result',
      );
      await tester.tap(find.byType(FilmCard));
      await settle(tester);

      await waitUntil(
        tester,
        () => video.speeds.contains(1.5),
        reason: 'the film to start at 1.5x',
      );
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
