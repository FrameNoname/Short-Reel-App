import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/settings_controller.dart';
import 'package:shortreel/views/auth/login_view.dart';

import 'app_shell_test.dart' show enterAsGuest, logIn, openTab;

Future<void> openSettings(WidgetTester tester) async {
  await openTab(tester, 'Profile');
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  test('settings start at normal speed with haptics on', () {
    final settings = SettingsController();
    expect(settings.defaultSpeed, 1);
    expect(settings.haptics, isTrue);
  });

  test('settings tell listeners only when something changes', () {
    final settings = SettingsController();
    var calls = 0;
    settings.addListener(() => calls++);
    settings.setDefaultSpeed(1);
    settings.setHaptics(enabled: true);
    expect(calls, 0);
    settings.setDefaultSpeed(1.5);
    settings.setHaptics(enabled: false);
    expect(calls, 2);
  });

  testWidgets('a signed-in person sees their account and can edit it', (
    tester,
  ) async {
    await logIn(tester, 'viewer01');
    await openSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Demo Viewer'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-name')), findsOneWidget);
  });

  testWidgets('a guest is offered a way to log in', (tester) async {
    await enterAsGuest(tester);
    await openSettings(tester);
    expect(find.text('Edit profile'), findsNothing);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('the haptics switch turns off and on', (tester) async {
    await logIn(tester, 'viewer01');
    await openSettings(tester);

    final toggle = find.byKey(const Key('settings-haptics'));
    expect(tester.widget<Switch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
  });

  testWidgets('the default speed applies to the films in the feed', (
    tester,
  ) async {
    await logIn(tester, 'viewer01');
    await openSettings(tester);
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'Home');
    // A film built after the change starts at the chosen speed.
    await tester.drag(find.textContaining('VIDEO ·'), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('1.5x speed'), findsOneWidget);
  });

  testWidgets('logging out asks first and can be cancelled', (tester) async {
    await logIn(tester, 'viewer01');
    await openSettings(tester);
    final logout = find.byKey(const Key('settings-logout'));
    await tester.scrollUntilVisible(
      logout,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('confirming log out returns to the login screen', (tester) async {
    await logIn(tester, 'viewer01');
    await openSettings(tester);
    final logout = find.byKey(const Key('settings-logout'));
    await tester.scrollUntilVisible(
      logout,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
  });
}
