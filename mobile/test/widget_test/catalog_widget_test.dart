// Person 5 — Widget test: the Series Jeen catalog.
// Runs the whole app against the real API (see test/widget_test/README.md).
// The backend's catalog routes run for real; only the outside provider is a
// stub in the test server.
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/api_app_harness.dart';

void main() {
  useApiApp();

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
}
