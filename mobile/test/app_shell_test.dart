import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/services/video_picker.dart';
import 'support/mock_repository.dart';
import 'package:shortreel/main.dart';
import 'package:shortreel/models/user.dart';
import 'package:shortreel/views/app_shell.dart';
import 'package:shortreel/views/auth/login_view.dart';
import 'package:shortreel/views/feed/login_gate_view.dart';
import 'package:shortreel/views/feed/unlock_success_view.dart';
import 'package:shortreel/views/profile/creator_dashboard_view.dart';
import 'package:shortreel/widgets/login_prompt.dart';

const passwords = {
  'viewer01': '6666',
  'mira.lens': '4444',
  'admin': '1111',
  'kestrel_studio': '2222',
};

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShortReelApp(
      repository: MockRepository(),
      pickVideos: () async => [
        PickedVideo(name: 'ep1.mp4', bytes: Uint8List(8)),
        PickedVideo(name: 'ep2.mp4', bytes: Uint8List(8)),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enterAsGuest(WidgetTester tester) async {
  await pumpApp(tester);
  await tester.tap(find.text('Watch free episodes without an account'));
  await tester.pumpAndSettle();
}

Future<void> logIn(WidgetTester tester, String username) async {
  await pumpApp(tester);
  await tester.enterText(find.byKey(const Key('login-username')), username);
  await tester.enterText(
    find.byKey(const Key('login-password')),
    passwords[username]!,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('tabsFor matches the role table', () {
    const base = [AppTab.feed, AppTab.search, AppTab.wallet, AppTab.profile];
    const withUpload = [
      AppTab.feed,
      AppTab.search,
      AppTab.upload,
      AppTab.wallet,
      AppTab.profile,
    ];
    expect(tabsFor(UserRole.guest), base);
    expect(tabsFor(UserRole.viewer), base);
    expect(tabsFor(UserRole.creator), withUpload);
    expect(tabsFor(UserRole.admin), [...withUpload, AppTab.admin]);
  });

  testWidgets('the app opens on the login screen', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('a wrong password shows the error box', (tester) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('login-username')),
      'mira.lens',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Username or password is incorrect'),
      findsOneWidget,
    );
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('register shows the validation messages', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('register-username')),
      'mira.lens',
    );
    await tester.enterText(find.byKey(const Key('register-password')), 'abc');
    await tester.enterText(find.byKey(const Key('register-confirm')), 'abd');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text("Passwords don't match."), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register-password')),
      'abcd1234',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirm')),
      'abcd1234',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('This username is already taken.'), findsOneWidget);
  });

  testWidgets('guest sees a login prompt on Wallet', (tester) async {
    await enterAsGuest(tester);
    await openTab(tester, 'Wallet');
    expect(find.byType(LoginPrompt), findsOneWidget);
  });

  testWidgets('guest sees a login prompt on Profile', (tester) async {
    await enterAsGuest(tester);
    await openTab(tester, 'Profile');
    expect(find.byType(LoginPrompt), findsOneWidget);
  });

  testWidgets('guest is asked to log in for a paid episode', (tester) async {
    await enterAsGuest(tester);
    await tester.tap(find.text('Eps').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('episode-3')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginGateView), findsOneWidget);
  });

  testWidgets('the Plus card in the episode list opens Plus', (tester) async {
    await enterAsGuest(tester);
    await tester.tap(find.text('Eps').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch every episode'));
    await tester.pumpAndSettle();
    expect(find.text('Watch every episode with Plus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewer sees the demo label on Wallet', (tester) async {
    await logIn(tester, 'viewer01');
    await openTab(tester, 'Wallet');
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.byType(LoginPrompt), findsNothing);
  });

  testWidgets('demo top-up updates the balance', (tester) async {
    await logIn(tester, 'viewer01');
    await openTab(tester, 'Wallet');
    expect(find.text('80'), findsOneWidget);
    await tester.tap(find.text('+100 free'));
    await tester.pumpAndSettle();
    expect(find.text('180'), findsOneWidget);
  });

  testWidgets('viewer unlocks an episode with coins', (tester) async {
    await logIn(tester, 'viewer01');
    await tester.tap(find.text('Eps').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('episode-5')));
    await tester.pumpAndSettle();
    expect(find.text('Unlock Episode 5'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock for 20 coins'));
    await tester.pumpAndSettle();
    expect(find.byType(UnlockSuccessView), findsOneWidget);
    expect(find.text('Episode 5 is yours'), findsOneWidget);

    await tester.tap(find.text('Play episode 5'));
    await tester.pumpAndSettle();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    expect(find.textContaining('EP 5'), findsOneWidget);
  });

  testWidgets('admin sees six tabs', (tester) async {
    await logIn(tester, 'admin');
    expect(find.byType(NavigationDestination), findsNWidgets(6));
  });

  testWidgets('viewer has no upload button', (tester) async {
    await logIn(tester, 'viewer01');
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('profile opens the creator studio', (tester) async {
    await logIn(tester, 'mira.lens');
    await openTab(tester, 'Profile');
    await tester.tap(find.text('Creator studio'));
    await tester.pumpAndSettle();
    expect(find.byType(CreatorDashboardView), findsOneWidget);
  });

  testWidgets('admin approves a film from the queue', (tester) async {
    await logIn(tester, 'admin');
    await openTab(tester, 'Admin');
    expect(find.text('Review queue (2)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').first);
    await tester.pumpAndSettle();
    expect(find.text('Review queue (1)'), findsOneWidget);
  });

  testWidgets('logout returns to the login screen', (tester) async {
    await logIn(tester, 'viewer01');
    await openTab(tester, 'Profile');
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
  });
}
