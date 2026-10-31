import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/mock_repository.dart';
import 'package:shortreel/l10n/thai.dart';
import 'package:shortreel/models/app_notification.dart';
import 'package:shortreel/views/notifications/notifications_view.dart';
import 'package:shortreel/views/profile/creator_profile_view.dart';
import 'package:shortreel/widgets/common.dart';

import 'app_shell_test.dart' show enterAsGuest, logIn;

void main() {
  group('repository', () {
    test('a creator starts with a few notifications, some unread', () {
      final repo = MockRepository();
      expect(repo.notificationsOf(2).length, 4);
      expect(repo.unreadNotificationCount(2), 2);
      expect(repo.unreadNotificationCount(5), 0);
    });

    test('marking read clears the count but keeps the list', () {
      final repo = MockRepository();
      repo.markNotificationsRead(2);
      expect(repo.unreadNotificationCount(2), 0);
      expect(repo.notificationsOf(2).length, 4);
    });

    test('a like tells the film\'s creator, once', () {
      final repo = MockRepository();
      final before = repo.notificationsOf(3).length;
      repo.toggleLike(6, 2);
      repo.toggleLike(6, 2); // unlike
      repo.toggleLike(6, 2); // like again
      final items = repo.notificationsOf(3);
      expect(items.length, before + 1);
      expect(items.first.kind, NotificationKind.like);
      expect(items.first.actorName, 'viewer01');
      expect(items.first.filmTitle, 'Paper Moons');
    });

    test('nobody is told about their own actions', () {
      final repo = MockRepository();
      final before = repo.notificationsOf(2).length;
      repo.toggleLike(2, 1);
      repo.addComment(2, 1, 'My own film');
      expect(repo.notificationsOf(2).length, before);
    });

    test('a comment tells the creator and a reply tells the commenter', () {
      final repo = MockRepository();
      final creatorBefore = repo.notificationsOf(2).length;
      repo.addComment(3, 1, 'Nice');
      expect(repo.notificationsOf(2).length, creatorBefore + 1);
      expect(repo.notificationsOf(2).first.kind, NotificationKind.comment);

      final viewerBefore = repo.notificationsOf(6).length;
      repo.addComment(3, 1, 'Agreed', parentId: 1);
      expect(repo.notificationsOf(6).length, viewerBefore + 1);
      expect(repo.notificationsOf(6).first.kind, NotificationKind.reply);
    });

    test('a new follower is announced', () {
      final repo = MockRepository();
      repo.toggleFollow(5, 2);
      final latest = repo.notificationsOf(2).first;
      expect(latest.kind, NotificationKind.follow);
      expect(latest.actorId, 5);
      expect(latest.message, 'started following you');
    });

    test('unlocking an episode tells the creator which one', () async {
      final repo = MockRepository();
      final episodes = await repo.episodes(2);
      final paid = episodes.firstWhere((e) => !e.isFree);
      await repo.unlock(6, paid.id);
      final latest = repo.notificationsOf(3).first;
      expect(latest.kind, NotificationKind.unlock);
      expect(latest.episodeNo, paid.episodeNo);
      expect(latest.message, startsWith('unlocked Episode ${paid.episodeNo}'));
    });

    test('a review result reaches the creator, but not twice', () {
      final repo = MockRepository();
      final pending = repo.reviewQueue().first;
      final before = repo.notificationsOf(pending.creatorId).length;
      repo.review(pending.id, 'approved');
      repo.review(pending.id, 'approved');
      final items = repo.notificationsOf(pending.creatorId);
      expect(items.length, before + 1);
      expect(items.first.kind, NotificationKind.approved);
      expect(items.first.hasActor, isFalse);
    });
  });

  group('timeAgo', () {
    final now = DateTime(2026, 10, 31, 12);
    test('says how long ago in the biggest fitting unit', () {
      expect(timeAgo(now, now: now), 'Just now');
      expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 9)), now: now),
        'Oct 22',
      );
    });
  });

  group('Thai', () {
    test('notification sentences are translated', () {
      expect(thaiOf('liked Salt & Signal'), 'ถูกใจ Salt & Signal');
      expect(thaiOf('started following you'), 'เริ่มติดตามคุณ');
      expect(thaiOf('2h ago'), '2 ชั่วโมงที่แล้ว');
      expect(
        thaiOf('unlocked Episode 3 of Salt & Signal'),
        'ปลดล็อกตอนที่ 3 ของ Salt & Signal',
      );
      expect(
        thaiOf('Paper Moons was approved'),
        'Paper Moons ได้รับการอนุมัติแล้ว',
      );
    });
  });

  group('screens', () {
    testWidgets('a guest has no bell', (tester) async {
      await enterAsGuest(tester);
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byKey(const Key('notification-bell')), findsNothing);
    });

    testWidgets('the bell counts what is new', (tester) async {
      await logIn(tester, 'kestrel_studio');
      expect(find.byKey(const Key('notification-bell')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('notification-badge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the inbox separates new from earlier and clears the bell', (
      tester,
    ) async {
      await logIn(tester, 'kestrel_studio');
      await tester.tap(find.byKey(const Key('notification-bell')));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.byKey(const Key('notification-new-1')), findsOneWidget);
      expect(find.byKey(const Key('notification-new-3')), findsNothing);
      expect(find.text('2h ago'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-badge')), findsNothing);
    });

    testWidgets('tapping a follow opens that person\'s channel', (
      tester,
    ) async {
      await logIn(tester, 'kestrel_studio');
      await tester.tap(find.byKey(const Key('notification-bell')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notification-3')));
      await tester.pumpAndSettle();
      expect(find.byType(CreatorProfileView), findsOneWidget);
      expect(find.text('@viewer01'), findsWidgets);
    });

    testWidgets('tapping a like opens the film', (tester) async {
      await logIn(tester, 'kestrel_studio');
      await tester.tap(find.byKey(const Key('notification-bell')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notification-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('VIDEO ·'), findsOneWidget);
    });

    testWidgets('someone with nothing new sees an empty inbox', (tester) async {
      await logIn(tester, 'admin');
      await tester.tap(find.byKey(const Key('notification-bell')));
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet.'), findsOneWidget);
    });

    testWidgets('a viewer is told about a reply', (tester) async {
      await logIn(tester, 'viewer01');
      await tester.tap(find.byKey(const Key('notification-bell')));
      await tester.pumpAndSettle();
      expect(find.textContaining('replied to your comment'), findsOneWidget);
    });
  });
}
