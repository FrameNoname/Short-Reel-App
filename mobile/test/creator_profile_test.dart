import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/profile/creator_profile_view.dart';

import 'app_shell_test.dart' show enterAsGuest, logIn, openTab;

void main() {
  testWidgets('the creator avatar opens their channel with their films', (
    tester,
  ) async {
    await enterAsGuest(tester);
    await tester.tap(find.byKey(const Key('channel-avatar')));
    await tester.pumpAndSettle();

    expect(find.byType(CreatorProfileView), findsOneWidget);
    expect(find.text('@kestrel_studio'), findsOneWidget);
    expect(find.text('Salt & Signal'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets('an admin channel carries the verified check', (tester) async {
    await enterAsGuest(tester);
    await openTab(tester, 'Search');
    await tester.tap(find.text('ShortReel Intro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('channel-avatar')));
    await tester.pumpAndSettle();

    expect(find.byType(CreatorProfileView), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsWidgets);
    expect(find.text('Official Short Reel channel'), findsOneWidget);
  });

  testWidgets('a guest who taps Follow is sent to log in', (tester) async {
    await enterAsGuest(tester);
    await tester.tap(find.byKey(const Key('channel-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-follow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-username')), findsOneWidget);
  });

  testWidgets('a viewer can follow and unfollow from the channel', (
    tester,
  ) async {
    await logIn(tester, 'viewer01');
    await tester.tap(find.byKey(const Key('channel-avatar')));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('profile-follow'));
    final startedFollowing = tester.widget(button) is OutlinedButton;

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.widget(button) is OutlinedButton, !startedFollowing);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.widget(button) is OutlinedButton, startedFollowing);
  });
}
