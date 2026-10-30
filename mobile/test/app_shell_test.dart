import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'package:shortreel/models/user.dart';
import 'package:shortreel/views/app_shell.dart';
import 'package:shortreel/views/profile/creator_dashboard_view.dart';
import 'package:shortreel/widgets/login_prompt.dart';

Future<void> pumpShell(WidgetTester tester, UserRole role) {
  return tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthController(role: role),
      child: const MaterialApp(home: AppShell()),
    ),
  );
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
    expect(tabsFor(UserRole.guest), base);
    expect(tabsFor(UserRole.viewer), base);
    expect(tabsFor(UserRole.creator), [...base, AppTab.upload]);
    expect(tabsFor(UserRole.admin), [...base, AppTab.upload, AppTab.admin]);
  });

  testWidgets('guest sees a login prompt on Wallet', (tester) async {
    await pumpShell(tester, UserRole.guest);
    await openTab(tester, 'Wallet');
    expect(find.byType(LoginPrompt), findsOneWidget);
  });

  testWidgets('guest sees a login prompt on Profile', (tester) async {
    await pumpShell(tester, UserRole.guest);
    await openTab(tester, 'Profile');
    expect(find.byType(LoginPrompt), findsOneWidget);
  });

  testWidgets('viewer sees the demo label on Wallet', (tester) async {
    await pumpShell(tester, UserRole.viewer);
    await openTab(tester, 'Wallet');
    expect(find.textContaining('Demo'), findsOneWidget);
    expect(find.byType(LoginPrompt), findsNothing);
  });

  testWidgets('admin sees six tabs', (tester) async {
    await pumpShell(tester, UserRole.admin);
    expect(find.byType(NavigationDestination), findsNWidgets(6));
  });

  testWidgets('profile opens the creator dashboard', (tester) async {
    await pumpShell(tester, UserRole.creator);
    await openTab(tester, 'Profile');
    await tester.tap(find.text('Creator dashboard'));
    await tester.pumpAndSettle();
    expect(find.byType(CreatorDashboardView), findsOneWidget);
  });
}
