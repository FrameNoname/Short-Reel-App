import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'support/mock_repository.dart';
import 'package:shortreel/main.dart';
import 'package:shortreel/models/episode.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/services/video_picker.dart';

import 'app_shell_test.dart' show logIn, openTab;
import 'upload_price_test.dart' show fillDetails, openUpload, reveal;

/// Fails the first reads of a film's episodes, like a dropped connection.
class _FlakyRepo extends MockRepository {
  int failures = 1;

  @override
  Future<List<Episode>> episodes(int filmId) async {
    if (failures > 0) {
      failures--;
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Cannot reach the server',
      );
    }
    return super.episodes(filmId);
  }
}

Future<void> _pumpWith(WidgetTester tester, MockRepository repo) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShortReelApp(
      repository: repo,
      pickVideos: () async => [PickedVideo(name: 'a.mp4', bytes: Uint8List(8))],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, String user, String password) async {
  await tester.enterText(find.byKey(const Key('login-username')), user);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'editing a film: a failed episode load shows an error, blocks saving, and retry recovers',
    (tester) async {
      final repo = _FlakyRepo();
      await _pumpWith(tester, repo);
      await _login(tester, 'mira.lens', '4444');
      await openTab(tester, 'Profile');
      await tester.tap(find.text('Creator studio'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit film').last);
      await tester.pumpAndSettle();
      repo.failures = 1; // the edit screen's own read fails once
      await tester.tap(find.text('Edit film').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('episodes-error')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('upload-prompt')),
        'Prompt: last tram',
      );
      await tester.pumpAndSettle();
      final save = find.byType(FilledButton).last;
      expect(
        tester.widget<FilledButton>(save).onPressed,
        isNull,
        reason: 'cannot save before the episodes are known',
      );

      await tester.tap(find.byKey(const Key('episodes-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('episodes-error')), findsNothing);
      expect(find.text('Episode pricing'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('upload-prompt')),
        'Prompt: last tram',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('the upload form refuses a price above 500 and accepts 500', (
    tester,
  ) async {
    await openUpload(tester);
    await fillDetails(tester);
    final price = find.byKey(const Key('episode-2-price'));
    await reveal(tester, price);

    await tester.enterText(price, '501');
    await tester.pumpAndSettle();
    expect(find.text('Enter 1 to 500 coins.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              'Set a price for every paid episode',
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(price, '500');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit for review'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'when the session expires every screen above the root is closed',
    (tester) async {
      await logIn(tester, 'mira.lens');
      await openTab(tester, 'Profile');
      await tester.tap(find.text('Creator studio'));
      await tester.pumpAndSettle();
      expect(find.text('Creator studio'), findsWidgets);

      final auth = Provider.of<AuthController>(
        tester.element(find.byType(Scaffold).first),
        listen: false,
      );
      auth.sessionExpired();
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'no page may read a user that is gone',
      );
      expect(find.text('Creator studio'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
      expect(ShortReelApp.navigatorKey.currentState!.canPop(), isFalse);
    },
  );

  testWidgets(
    'a film waiting for review offers only the actions the server allows',
    (tester) async {
      await logIn(tester, 'admin');
      await openTab(tester, 'Admin');
      expect(find.widgetWithText(FilledButton, 'Approve'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Reject'), findsWidgets);
      expect(
        find.text('Take down'),
        findsNothing,
        reason: 'pending -> taken_down is not allowed',
      );
    },
  );

  testWidgets(
    'after an upload the Creator studio lists the new film as Pending',
    (tester) async {
      await openUpload(
        tester,
      ); // logs in as kestrel_studio, opens the Upload tab
      await fillDetails(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('Submitted. Waiting for admin review.'), findsOneWidget);

      // Open the studio from Profile, press + Upload, upload a second film and come back.
      await openTab(tester, 'Profile');
      await tester.tap(find.text('Creator studio'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('+ Upload'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('+ Upload'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('upload-title')),
        'Refresh Check Film',
      );
      await tester.enterText(
        find.byKey(const Key('upload-prompt')),
        'A prompt',
      );
      await tester.tap(find.text('Choose episode videos'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit for review'));
      await tester.pumpAndSettle();

      // Back on the studio without reopening it: the new film is there.
      await tester.scrollUntilVisible(
        find.text('Refresh Check Film'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Refresh Check Film'), findsOneWidget);
    },
  );

  testWidgets(
    'Profile re-reads its lists every time its tab becomes visible again',
    (tester) async {
      final repo = _CountingRepo();
      await _pumpWith(tester, repo);
      await _login(tester, 'viewer01', '6666');
      await openTab(tester, 'Profile');
      await tester.pumpAndSettle();
      final first = repo.libraryReads;
      expect(first, greaterThan(0));

      await openTab(tester, 'Home');
      await tester.pumpAndSettle();
      expect(
        repo.libraryReads,
        first,
        reason: 'nothing reloads while it is hidden',
      );
      await openTab(tester, 'Profile');
      await tester.pumpAndSettle();
      expect(
        repo.libraryReads,
        greaterThan(first),
        reason: 'coming back reloads saved/unlocked/following',
      );
    },
  );
}

/// Counts how often the saved/unlocked/following lists are read.
class _CountingRepo extends MockRepository {
  int libraryReads = 0;

  @override
  Future<void> refreshLibrary(int userId) async {
    libraryReads++;
    return super.refreshLibrary(userId);
  }
}
