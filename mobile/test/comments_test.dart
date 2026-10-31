import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/mock_repository.dart';

import 'app_shell_test.dart' show enterAsGuest, logIn;

Future<void> openComments(WidgetTester tester) async {
  await tester.tap(find.text('312'));
  await tester.pumpAndSettle();
}

void main() {
  group('repository', () {
    test('liking a comment counts once per person and can be undone', () {
      final repo = MockRepository();
      final before = repo.commentLikeCount(1);
      repo.toggleCommentLike(6, 1);
      expect(repo.isCommentLiked(6, 1), isTrue);
      expect(repo.commentLikeCount(1), before + 1);
      repo.toggleCommentLike(6, 1);
      expect(repo.isCommentLiked(6, 1), isFalse);
      expect(repo.commentLikeCount(1), before);
    });

    test('a reply is stored under its parent and counts as a comment', () {
      final repo = MockRepository();
      final before = repo.commentsOf(1).length;
      repo.addComment(4, 1, 'Agreed', parentId: 1);
      final comments = repo.commentsOf(1);
      expect(comments.length, before + 1);
      expect(comments.first.parentId, 1);
      expect(comments.first.isReply, isTrue);
    });

    test('a reply to a comment on another film is refused', () {
      final repo = MockRepository();
      expect(() => repo.addComment(4, 1, 'Hi', parentId: 2), throwsException);
    });

    test('deleting a comment deletes its replies and their likes', () async {
      final repo = MockRepository();
      repo.addComment(4, 1, 'First reply', parentId: 1);
      repo.addComment(3, 1, 'Second reply', parentId: 1);
      final replyId = repo.commentsOf(1).first.id;
      repo.toggleCommentLike(6, replyId);
      final filmBefore = (await repo.films()).firstWhere((f) => f.id == 1);

      repo.removeComment(1);
      expect(repo.commentsOf(1), isEmpty);
      expect(repo.commentLikeCount(replyId), 0);
      final filmAfter = (await repo.films()).firstWhere((f) => f.id == 1);
      expect(filmAfter.commentCount, filmBefore.commentCount - 3);
    });
  });

  group('sheet', () {
    testWidgets('a viewer likes and unlikes a comment', (tester) async {
      await logIn(tester, 'viewer01');
      await openComments(tester);

      final like = find.byKey(const Key('comment-like-1'));
      expect(
        find.descendant(of: like, matching: find.text('1')),
        findsOneWidget,
      );
      await tester.tap(like);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: like, matching: find.text('2')),
        findsOneWidget,
      );
      await tester.tap(like);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: like, matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('a reply shows the target and joins the thread', (
      tester,
    ) async {
      await logIn(tester, 'viewer01');
      await openComments(tester);

      await tester.tap(find.byKey(const Key('comment-reply-1')));
      await tester.pumpAndSettle();
      expect(find.text('Replying to @viewer01'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('comment-input')),
        'Totally agree',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comment-send')));
      await tester.pumpAndSettle();

      expect(find.text('Totally agree'), findsOneWidget);
      expect(find.text('Replying to @viewer01'), findsNothing);
    });

    testWidgets('cancelling a reply clears the banner', (tester) async {
      await logIn(tester, 'viewer01');
      await openComments(tester);
      await tester.tap(find.byKey(const Key('comment-reply-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reply-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Replying to @viewer01'), findsNothing);
    });

    testWidgets('deleting a comment takes its replies with it', (tester) async {
      await logIn(tester, 'viewer01');
      await openComments(tester);
      await tester.tap(find.byKey(const Key('comment-reply-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('comment-input')), 'A reply');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comment-send')));
      await tester.pumpAndSettle();
      expect(find.text('A reply'), findsOneWidget);

      await tester.tap(find.byKey(const Key('comment-delete-1')));
      await tester.pumpAndSettle();
      expect(find.text('A reply'), findsNothing);
      expect(find.text('No comments yet. Say something.'), findsOneWidget);
    });

    testWidgets('a guest who taps like is sent to log in', (tester) async {
      await enterAsGuest(tester);
      await openComments(tester);
      await tester.tap(find.byKey(const Key('comment-like-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-username')), findsOneWidget);
    });

    testWidgets('a guest who taps reply is sent to log in', (tester) async {
      await enterAsGuest(tester);
      await openComments(tester);
      await tester.tap(find.byKey(const Key('comment-reply-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-username')), findsOneWidget);
    });
  });
}
