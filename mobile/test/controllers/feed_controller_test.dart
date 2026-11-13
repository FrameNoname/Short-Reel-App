// Person 2: FeedController (feed, player state, likes, comments).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/feed_controller.dart';
import 'package:shortreel/models/catalog.dart';
import 'package:shortreel/models/episode.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/services/api_client.dart';

import '../support/fake_repository.dart';
import '../support/helpers.dart';

Episode _episode(int filmId, int no) => Episode.fromJson({
  'id': filmId * 100 + no,
  'film_id': filmId,
  'episode_no': no,
  'duration_sec': 60,
  'is_free': true,
  'price_coins': 0,
});

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

  group('FeedController', () {
    test('load lists the films and stops loading', () async {
      repo.filmList = [testFilm(1, 'A'), testFilm(2, 'B')];
      final feed = FeedController(repo);
      await feed.load(null);
      expect(feed.films.map((f) => f.id), [1, 2]);
      expect(feed.isLoading, isFalse);
      expect(feed.error, isNull);
    });

    test('preferred genres come first, each group keeps its order', () async {
      repo.filmList = [
        testFilm(1, 'A', genre: 'Drama'),
        testFilm(2, 'B', genre: 'Sci-fi'),
        testFilm(3, 'C', genre: 'Drama'),
        testFilm(4, 'D', genre: 'Sci-fi'),
      ];
      final feed = FeedController(repo)..preferGenres({'Sci-fi'});
      await feed.load(2);
      expect(feed.films.map((f) => f.id), [2, 4, 1, 3]);
    });

    test('a failed load empties the feed and shows why', () async {
      repo.filmList = [testFilm(1, 'A')];
      final feed = FeedController(repo);
      await feed.load(null);
      repo.filmsError = serverDown;
      await feed.load(null);
      expect(feed.films, isEmpty);
      expect(feed.error, 'Cannot reach the server');
      expect(feed.isLoading, isFalse);
    });

    test('a stale session error is left for the login to handle', () async {
      repo.filmsError = const ApiException(
        code: staleSessionCode,
        message: 'Signed out',
      );
      final feed = FeedController(repo);
      await feed.load(null);
      expect(feed.error, isNull);
    });

    test('a slow older load does not replace a newer one', () async {
      repo.filmList = [testFilm(2, 'New')];
      final gate = repo.filmGates[''] = Completer<List<Film>>();
      final feed = FeedController(repo);
      final old = feed.load(null);
      repo.filmGates.clear();
      await feed.load(null);

      gate.complete([testFilm(1, 'Old')]);
      await old;

      expect(feed.films.map((f) => f.title), ['New']);
    });

    test('next episode follows the real numbers, or the count', () {
      final feed = FeedController(repo);
      expect(feed.episodeAfter(1, 2, fallbackCount: 3), 3);
      expect(feed.episodeAfter(1, 3, fallbackCount: 3), isNull);

      feed.learnEpisodes(1, [5, 1, 3]);
      expect(feed.episodeAfter(1, 1, fallbackCount: 99), 3);
      expect(feed.episodeAfter(1, 3, fallbackCount: 99), 5);
      expect(feed.episodeAfter(1, 5, fallbackCount: 99), isNull);
    });

    test('play and resume move the current episode; reset forgets it', () {
      final feed = FeedController(repo);
      expect(feed.currentEpisodeOf(1), 1);
      feed.play(_episode(1, 4));
      expect(feed.currentEpisodeOf(1), 4);
      feed.resume(1, 6);
      expect(feed.currentEpisodeOf(1), 6);

      feed.learnEpisodes(1, [1, 9]);
      feed.reset();
      expect(feed.currentEpisodeOf(1), 1);
      expect(feed.episodeAfter(1, 1, fallbackCount: 2), 2);
      expect(feed.films, isEmpty);
    });

    test(
      'a like or comment swaps in the repository copy of the film',
      () async {
        repo.filmList = [testFilm(1, 'A'), testFilm(2, 'B')];
        final feed = FeedController(repo);
        await feed.load(2);
        repo.latest[1] = testFilm(1, 'A', likes: 1);

        await feed.toggleLike(2, 1);
        expect(feed.films.first.likeCount, 1);
        expect(feed.films.last.title, 'B');

        await feed.addComment(2, 2, 'nice');
        await feed.removeComment(2, 7);
        expect(
          repo.calls,
          containsAll(['toggleLike 1', 'addComment 2 nice', 'removeComment 7']),
        );
      },
    );
  });

  group('FeedController reads for the views', () {
    test('pass through to the repository', () async {
      final feed = FeedController(repo);
      expect(feed.playsVideo, isTrue);
      expect(feed.isLiked(2, 1), isTrue);
      expect(feed.isSaved(2, 1), isFalse);

      final episode = (await feed.episodes(3)).single;
      expect(feed.accessOf(null, episode), EpisodeAccess.locked);
      expect(feed.accessOf(2, episode), EpisodeAccess.free);
      expect((await feed.playback(31)).streamUrl, '/videos/31.mp4');

      final film = testFilm(1, 'A');
      expect(feed.catalogEpisodeLocked(film, 5), isFalse);
      expect(feed.catalogEpisodeLocked(film, 6), isTrue);

      await feed.loadComments(3);
      expect(feed.commentsOf(3).single.body, 'film 3');
      expect(repo.calls, contains('loadComments 3'));
    });

    test('a catalog series becomes one feed film, reused', () {
      final feed = FeedController(repo);
      const drama = CatalogDrama(
        id: 21,
        title: 'Desert',
        description: null,
        episodeCount: 60,
        genres: [],
        posterUrl: null,
        thaiDub: true,
        thaiSub: false,
      );
      final film = feed.catalogFilm(drama);
      expect(film.catalogDramaId, 21);
      expect(identical(feed.catalogFilm(drama), film), isTrue);
    });

    test('saving notifies so the heart and lists redraw', () async {
      final feed = FeedController(repo);
      var notified = 0;
      feed.addListener(() => notified++);
      await feed.toggleSave(2, 4);
      expect(notified, 1);
      expect(repo.calls, contains('toggleSave 4'));
    });
  });
}
