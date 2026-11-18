// Person 6 — Widget test: the admin screens.
// Runs the whole app against the real API (see test/widget_test/README.md).
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/views/admin/admin_settings_view.dart';

import '../support/api_app_harness.dart';

void main() {
  useApiApp();

  Future<void> openAdmin(WidgetTester tester) async {
    await logIn(tester, 'admin');
    await openTab(tester, 'Admin');
  }

  group('admin', () {
    testWidgets('the admin gets the Admin tab and no Wallet', (tester) async {
      await logIn(tester, 'admin');

      expect(navTab('Admin'), findsOneWidget);
      expect(navTab('Wallet'), findsNothing);
      await waitFor(tester, find.text(firstFilm));
      await closeApp(tester);
    });

    testWidgets('the dashboard shows the seeded sales', (tester) async {
      await openAdmin(tester);

      await waitFor(tester, find.text(r'$0.99'));
      expect(text('80 coins'), findsWidgets);
      expect(find.text('Salt & Signal'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('takes a film down and the API drops it', (tester) async {
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

      expect(await serverText('/films'), isNot(contains('Glass Harbour')));
      await closeApp(tester);
    });

    testWidgets('deletes a comment', (tester) async {
      await openAdmin(tester);
      await tester.tap(text('Comments'));
      await waitFor(tester, find.text('Love the paper-cut style.'));

      final rows = find.ancestor(
        of: find.text('Love the paper-cut style.'),
        matching: find.byType(Row),
      );
      await tester.tap(
        find.descendant(of: rows, matching: find.byTooltip(th('Delete'))).first,
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, th('Delete')));
      await waitFor(tester, text('Comment deleted.'));

      expect(
        await serverText('/films/2/comments'),
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
