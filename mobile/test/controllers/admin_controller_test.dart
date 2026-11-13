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
