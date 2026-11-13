// Person 6: AdminController (sales, films, comments, settings, Series Jeen).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/admin_controller.dart';
import 'package:shortreel/data/app_repository.dart';

import '../support/fake_repository.dart';
import '../support/helpers.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

  group('AdminController', () {
    const film = AdminFilm(
      id: 1,
      title: 'Salt & Signal',
      posterUrl: null,
      takenDown: false,
      episodeCount: 8,
      likeCount: 1,
      commentCount: 1,
      coinsSpent: 40,
    );

    test('load reads the sales or keeps the error', () async {
      final admin = AdminController(repo);
      await admin.load();
      expect(admin.sales.totalUsd, 4.99);
      expect(admin.error, isNull);

      repo.adminError = serverDown;
      await admin.load();
      expect(admin.error, 'Cannot reach the server');
      expect(admin.isLoading, isFalse);
    });

    test('taking a film down updates the list in place', () async {
      repo.adminFilmList = [film];
      final admin = AdminController(repo);
      await admin.loadFilms();

      await admin.setTakenDown(film, true);

      expect(repo.calls, contains('setTakenDown 1 true'));
      expect(admin.films.single.takenDown, isTrue);
    });

    test('a failed take-down leaves the list as it was', () async {
      repo.adminFilmList = [film];
      final admin = AdminController(repo);
      await admin.loadFilms();
      repo.adminError = serverDown;

      await expectLater(admin.setTakenDown(film, true), throwsA(serverDown));
      expect(admin.films.single.takenDown, isFalse);
    });

    test('deleting a comment removes only that one', () async {
      final now = DateTime(2026, 11, 8);
      repo.commentList = [
        AdminComment(
          id: 1,
          body: 'a',
          username: 'u',
          filmTitle: 'F',
          createdAt: now,
        ),
        AdminComment(
          id: 2,
          body: 'b',
          username: 'u',
          filmTitle: 'F',
          createdAt: now,
        ),
      ];
      final admin = AdminController(repo);
      await admin.loadComments();
      await admin.deleteComment(admin.comments.first);
      expect(admin.comments.map((c) => c.id), [2]);
    });

    group('comments', () {
      List<AdminComment> make(int count, {int filmId = 1}) => [
        for (var i = count; i >= 1; i--)
          AdminComment(
            id: i,
            body: 'comment $i',
            username: i.isEven ? 'even' : 'odd',
            filmId: i % 3 == 0 ? 9 : filmId,
            filmTitle: i % 3 == 0 ? 'Nine' : 'One',
            createdAt: DateTime(2026, 11, 8),
          ),
      ];

      test('load more adds the next page until there is none', () async {
        repo.commentList = make(45);
        final admin = AdminController(repo);
        await admin.loadComments();
        expect(admin.comments, hasLength(AdminController.commentsPageSize));
        expect(admin.commentsHasMore, isTrue);

        await admin.loadMoreComments();
        expect(admin.comments, hasLength(40));
        await admin.loadMoreComments();
        expect(admin.comments, hasLength(45));
        expect(admin.commentsHasMore, isFalse);
        expect(admin.comments.map((c) => c.id).toSet(), hasLength(45));

        final asked = repo.calls.length;
        await admin.loadMoreComments();
        expect(repo.calls, hasLength(asked));
      });

      test('a deleted comment does not make load more skip one', () async {
        repo.commentList = make(25);
        final admin = AdminController(repo);
        await admin.loadComments();
        final gone = admin.comments.first;
        await admin.deleteComment(gone);
        repo.commentList = [
          for (final c in repo.commentList)
            if (c.id != gone.id) c,
        ];
        await admin.loadMoreComments();
        expect(admin.comments, hasLength(24));
        expect(admin.commentsHasMore, isFalse);
      });

      test('a page that repeats a held comment is not shown twice', () async {
        repo.commentList = make(25);
        final admin = AdminController(repo);
        await admin.loadComments();
        // A new comment arrives, pushing the oldest held one onto page two.
        repo.commentList = [
          AdminComment(
            id: 26,
            body: 'new',
            username: 'u',
            filmTitle: 'One',
            createdAt: DateTime(2026, 11, 9),
          ),
          ...repo.commentList,
        ];
        await admin.loadMoreComments();
        expect(admin.comments.map((c) => c.id).toSet(), hasLength(25));
        expect(admin.comments, hasLength(25));
      });

      test('filtering by film asks the server for that film only', () async {
        repo.commentList = make(12);
        final admin = AdminController(repo);
        await admin.loadComments();
        await admin.filterCommentsByFilm(9, title: 'Nine');
        expect(admin.commentsFilmId, 9);
        expect(admin.commentsFilmTitle, 'Nine');
        expect(repo.calls.last, contains('film=9 offset=0'));
        expect(admin.comments.map((c) => c.filmId), everyElement(9));
        expect(admin.comments, hasLength(4));

        await admin.filterCommentsByFilm(null);
        expect(admin.commentsFilmTitle, isNull);
        expect(admin.comments, hasLength(12));
      });

      test('search filters the loaded comments without asking', () async {
        repo.commentList = make(6);
        final admin = AdminController(repo);
        await admin.loadComments();
        final asked = repo.calls.length;
        admin.searchComments('  NINE ');
        expect(admin.visibleComments.map((c) => c.id), [6, 3]);
        // The author's name is not searched.
        admin.searchComments('even');
        expect(admin.visibleComments, isEmpty);
        admin.searchComments('');
        expect(admin.visibleComments, hasLength(6));
        expect(repo.calls, hasLength(asked));
      });

      test('a failed load more keeps what is shown', () async {
        repo.commentList = make(25);
        final admin = AdminController(repo);
        await admin.loadComments();
        repo.adminError = serverDown;
        await admin.loadMoreComments();
        expect(admin.comments, hasLength(20));
        expect(admin.commentsError, isNotNull);
        expect(admin.commentsLoadingMore, isFalse);
      });

      test('reset clears the film filter and search', () async {
        repo.commentList = make(6);
        final admin = AdminController(repo);
        await admin.filterCommentsByFilm(9, title: 'Nine');
        admin.searchComments('x');
        admin.reset();
        expect(admin.commentsFilmId, isNull);
        expect(admin.commentsQuery, isEmpty);
        expect(admin.comments, isEmpty);
      });
    });

    test('settings and coin packs load together and save', () async {
      repo.adminPacks = const [
        AdminCoinPack(
          id: 1,
          name: 'Starter',
          coins: 60,
          priceUsd: 0.99,
          soldCount: 2,
        ),
      ];
      final admin = AdminController(repo);
      await admin.loadSettings();
      expect(admin.coinPacks.single.name, 'Starter');

      await admin.saveSettings(const AdminSettings(catalogPriceCoins: 15));
      expect(admin.settings.catalogPriceCoins, 15);

      await admin.saveCoinPack(name: 'Mega', coins: 999, priceUsd: 9.99);
      expect(admin.coinPacks.map((p) => p.name), ['Starter', 'Mega']);

      await admin.deleteCoinPack(admin.coinPacks.first);
      expect(admin.coinPacks.map((p) => p.name), ['Mega']);
    });

    test('reset forgets everything', () async {
      repo.adminFilmList = [film];
      final admin = AdminController(repo);
      await admin.load();
      await admin.loadFilms();
      admin.reset();
      expect(admin.films, isEmpty);
      expect(admin.sales.totalUsd, 0);
    });
  });

  group('AdminController, Series Jeen search', () {
    const found = AdminFilm(
      id: 0,
      title: 'Drama',
      posterUrl: null,
      takenDown: false,
      episodeCount: 80,
      likeCount: 0,
      commentCount: 0,
      coinsSpent: 0,
      catalogDramaId: 21,
    );

    test('an empty word clears the results without asking', () async {
      repo.searchResults = [found];
      final admin = AdminController(repo);
      await admin.searchCatalog(' love ');
      expect(admin.searchQuery, 'love');
      expect(admin.searchResults, [found]);

      await admin.searchCatalog('  ');
      expect(admin.searchResults, isEmpty);
      expect(repo.calls.where((c) => c.startsWith('searchCatalog')).length, 1);
    });

    test('a failed search shows why', () async {
      repo.adminError = serverDown;
      final admin = AdminController(repo);
      await admin.searchCatalog('love');
      expect(admin.searchError, 'Cannot reach the server');
      expect(admin.searchLoading, isFalse);
    });

    test('a slow answer for an old word is dropped', () async {
      final gate = repo.searchGates['old'] = Completer<List<AdminFilm>>();
      repo.searchResults = [found];
      final admin = AdminController(repo);
      final old = admin.searchCatalog('old');
      await admin.searchCatalog('new');
      gate.complete(const []);
      await old;
      expect(admin.searchQuery, 'new');
      expect(admin.searchResults, [found]);
    });

    test('taking down a found series marks it and reloads the list', () async {
      repo.searchResults = [found];
      final admin = AdminController(repo);
      await admin.searchCatalog('drama');
      repo.adminFilmList = [found.withTakenDown(true)];

      await admin.setTakenDown(found, true);

      expect(admin.searchResults.single.takenDown, isTrue);
      expect(admin.films.single.catalogDramaId, 21);
    });

    test('episodes and price changes go to the repository', () async {
      final admin = AdminController(repo);
      await admin.episodesOf(1);
      const episode = AdminEpisode(
        id: 9,
        episodeNo: 3,
        title: null,
        isFree: false,
        priceCoins: 20,
        unlockCount: 0,
      );
      final saved = await admin.updateEpisode(
        episode,
        isFree: false,
        priceCoins: 7,
      );
      expect(saved.priceCoins, 7);
      expect(
        repo.calls,
        containsAll(['adminEpisodes 1', 'adminUpdateEpisode 9']),
      );
    });
  });
}
