// Person 1 — Widget test: signing in, creating an account, settings and logout.
// Runs the whole app against the real API (see test/widget_test/README.md).
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/app_shell.dart';
import 'package:shortreel/views/auth/login_view.dart';
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

  group('settings and logout', () {
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
  });
}
