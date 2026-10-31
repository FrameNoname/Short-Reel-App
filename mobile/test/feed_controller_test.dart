import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/feed_controller.dart';
import 'package:shortreel/data/mock_repository.dart';
import 'package:shortreel/widgets/ai_label_badge.dart';
import 'package:shortreel/widgets/common.dart';

void main() {
  test('liking updates the count without reloading the feed', () async {
    final feed = FeedController(MockRepository());
    await feed.load(6);
    final before = feed.films.first.likeCount;
    final loadingStates = <bool>[];
    feed.addListener(() => loadingStates.add(feed.isLoading));

    await feed.toggleLike(6, feed.films.first.id);

    expect(feed.films.first.likeCount, before + 1);
    expect(loadingStates, isNot(contains(true)));
  });

  testWidgets('a poster with built-in artwork gets no second AI badge', (
    tester,
  ) async {
    final films = await MockRepository().films();
    final withArt = films.firstWhere((f) => f.posterAsset != null);
    await tester.pumpWidget(MaterialApp(home: FilmPoster(film: withArt)));
    expect(find.byType(AiLabelBadge), findsNothing);
  });

  testWidgets('a poster without artwork shows the AI badge', (tester) async {
    final films = await MockRepository().films();
    final plain = films.firstWhere((f) => f.posterAsset == null);
    await tester.pumpWidget(MaterialApp(home: FilmPoster(film: plain)));
    expect(find.byType(AiLabelBadge), findsOneWidget);
  });
}
