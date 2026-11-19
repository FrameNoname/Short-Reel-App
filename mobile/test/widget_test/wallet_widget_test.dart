// Person 4 — Widget test: the wallet, coin packs and unlocking episodes.
// Runs the whole app against the real API (see test/widget_test/README.md).
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/app_shell.dart';
import 'package:shortreel/views/auth/login_view.dart';
import 'package:shortreel/views/wallet/top_up_view.dart';

import '../support/api_app_harness.dart';

void main() {
  useApiApp();

  group('wallet', () {
    testWidgets('a guest is asked to log in', (tester) async {
      await enterAsGuest(tester);
      await waitFor(tester, find.text(firstFilm));

      await openTab(tester, 'Wallet');
      await tester.tap(find.widgetWithText(FilledButton, th('Log in')));
      await settle(tester);
      expect(find.byType(LoginView), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('shows the balance and adds the free demo coins', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Wallet');
      await waitFor(tester, find.text('80'));

      await tester.tap(text('+100 free'));
      await waitFor(tester, find.text('180'));
      expect(
        await serverText('/wallet', username: 'viewer01'),
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
        await serverText('/wallet/transactions', username: 'viewer01'),
        contains('0.99'),
      );
      await closeApp(tester);
    });
  });

  group('unlocking', () {
    testWidgets('a viewer spends 20 coins on episode 3', (tester) async {
      await logIn(tester, 'viewer01', allowTestFontOverflow: true);
      await openEpisode(tester, 3);

      await tester.tap(text('Unlock for 20 coins'));
      await waitFor(tester, text('Episode 3 is yours'));

      expect(
        await serverText('/wallet', username: 'viewer01'),
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
      await register(tester, 'pat', 'abc12345', allowTestFontOverflow: true);
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

    testWidgets('the wallet offers Try again while the server is down', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await waitFor(tester, find.text(firstFilm));
      await serverDown(true);
      await openTab(tester, 'Wallet');
      await waitFor(tester, text('Try again'));

      await serverDown(false);
      await tester.tap(text('Try again'));
      await waitFor(tester, find.text('80'));
      await closeApp(tester);
    });
  });
}
