import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/film_filter.dart';
import 'package:shortreel/data/mock_repository.dart';
import 'package:shortreel/main.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/models/transaction.dart';
import 'package:shortreel/services/api_client.dart';

import 'app_shell_test.dart' show logIn, openTab;

const _down = ApiException(
  code: 'NETWORK_ERROR',
  message: 'Cannot reach the server',
);

/// A mock whose backend can be switched off, like a server that is down.
class FlakyRepository extends MockRepository {
  bool down = true;

  @override
  Future<List<Film>> films([FilmFilter filter = const FilmFilter()]) async {
    if (down) throw _down;
    return super.films(filter);
  }

  @override
  Future<List<Transaction>> transactionsOf(int userId) async {
    if (down) throw _down;
    return super.transactionsOf(userId);
  }

  @override
  Future<List<Film>> reviewQueue() async {
    if (down) throw _down;
    return super.reviewQueue();
  }
}

Future<void> pumpFlaky(WidgetTester tester, FlakyRepository repo) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ShortReelApp(repository: repo));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the feed shows the error and Try again recovers', (
    tester,
  ) async {
    final repo = FlakyRepository();
    await pumpFlaky(tester, repo);
    await tester.tap(find.text('Watch free episodes without an account'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot reach the server'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repo.down = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Cannot reach the server'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('the wallet shows the error and Try again recovers', (
    tester,
  ) async {
    final repo = FlakyRepository()..down = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShortReelApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-username')), 'viewer01');
    await tester.enterText(find.byKey(const Key('login-password')), '6666');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    repo.down = true;
    await openTab(tester, 'Wallet');
    expect(find.text('Cannot reach the server'), findsOneWidget);

    repo.down = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Cannot reach the server'), findsNothing);
    expect(find.text('Ember Protocol, Episode 3'), findsOneWidget);
  });

  testWidgets('the admin review list shows the error and recovers', (
    tester,
  ) async {
    final repo = FlakyRepository();
    await pumpFlaky(tester, repo);
    await tester.enterText(find.byKey(const Key('login-username')), 'admin');
    await tester.enterText(find.byKey(const Key('login-password')), '1111');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Admin');

    expect(find.text('Cannot reach the server'), findsWidgets);
    repo.down = false;
    await tester.tap(find.text('Try again').last);
    await tester.pumpAndSettle();
    expect(find.text('Cannot reach the server'), findsNothing);
  });

  test('logIn helper is still exported for other tests', () {
    expect(logIn, isNotNull);
  });
}
