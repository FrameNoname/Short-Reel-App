import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_repository.dart';
import 'package:shortreel/models/user.dart';
import 'package:shortreel/views/profile/creator_profile_view.dart';

import 'app_shell_test.dart' show enterAsGuest, logIn, openTab;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('repository', () {
    test(
      'episode prices can be changed, and 0 makes an episode free',
      () async {
        final repo = MockRepository();
        final episodes = await repo.episodes(1);
        final paid = episodes.firstWhere((e) => !e.isFree);
        final free = episodes.firstWhere((e) => e.isFree);

        await repo.setEpisodePrices({paid.id: 45, free.id: 10});
        final after = await repo.episodes(1);
        expect(after.firstWhere((e) => e.id == paid.id).priceCoins, 45);
        expect(after.firstWhere((e) => e.id == free.id).isFree, isFalse);

        await repo.setEpisodePrices({paid.id: 0});
        expect(
          (await repo.episodes(1)).firstWhere((e) => e.id == paid.id).isFree,
          isTrue,
        );
      },
    );

    test('a price above 999 coins is refused', () async {
      final repo = MockRepository();
      final episode = (await repo.episodes(1)).first;
      await expectLater(
        repo.setEpisodePrices({episode.id: 1000}),
        throwsException,
      );
    });

    test('creator search matches names and ignores viewers', () {
      final repo = MockRepository();
      expect(repo.searchCreators('kestrel').map((u) => u.username), [
        'kestrel_studio',
      ]);
      expect(repo.searchCreators('SHORTREEL').single.role, UserRole.admin);
      expect(repo.searchCreators('viewer'), isEmpty);
      expect(repo.searchCreators('  '), isEmpty);
    });

    test('a profile update changes the name and bio', () async {
      final repo = MockRepository();
      final updated = await repo.updateProfile(
        6,
        displayName: ' Night Owl ',
        bio: 'Short films after dark',
      );
      expect(updated.displayName, 'Night Owl');
      expect(repo.userById(6)!.bio, 'Short films after dark');
    });

    test('a blank channel name is refused', () async {
      final repo = MockRepository();
      expect(
        repo.updateProfile(6, displayName: '   ', bio: ''),
        throwsException,
      );
    });
  });

  group('screens', () {
    testWidgets('searching finds a channel and opens it', (tester) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await tester.enterText(find.byType(TextField).first, 'kestrel');
      await tester.pumpAndSettle();

      expect(find.text('Channels'), findsOneWidget);
      await tester.tap(find.byKey(const Key('channel-2')));
      await tester.pumpAndSettle();
      expect(find.byType(CreatorProfileView), findsOneWidget);
    });

    testWidgets('no channels row when nothing matches', (tester) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Search');
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Channels'), findsNothing);
    });

    testWidgets('a viewer edits their profile', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Night Owl',
      );
      await tester.enterText(
        find.byKey(const Key('profile-bio')),
        'Watches late',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Profile saved.'), findsOneWidget);
      expect(find.text('Night Owl'), findsOneWidget);
      expect(find.text('Watches late'), findsOneWidget);
    });

    testWidgets('an empty name cannot be saved', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('profile-name')), '');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('a creator reprices an episode after upload', (tester) async {
      await logIn(tester, 'kestrel_studio');
      await openTab(tester, 'Profile');
      await tester.tap(find.text('Creator studio'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Edit film'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Edit film').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit film'));
      await tester.pumpAndSettle();

      final price = find.byKey(const Key('episode-3-price'));
      await reveal(tester, price);
      expect(tester.widget<TextField>(price).controller!.text, '20');
      await tester.enterText(price, '35');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Changes saved.'), findsOneWidget);
      expect(find.textContaining('20–35 coins'), findsOneWidget);
    });
  });
}
