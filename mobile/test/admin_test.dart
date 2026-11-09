// Person 6: the admin screens.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/admin_controller.dart';
import 'package:shortreel/data/app_repository.dart';

import 'support/fake_repository.dart';
import 'support/helpers.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

  group('Admin models', () {
    test('AdminFilm reads status as takenDown and can flip it', () {
      final film = AdminFilm.fromJson({
        'id': 1,
        'title': 'A',
        'poster_url': null,
        'status': 'taken_down',
        'episode_count': 8,
        'like_count': 1,
        'comment_count': 2,
        'coins_spent': 40,
      });
      expect(film.takenDown, isTrue);
      final live = film.withTakenDown(false);
      expect(live.takenDown, isFalse);
      expect(live.coinsSpent, 40);
    });

    test('AdminSettings round-trips through JSON and has defaults', () {
      const s = AdminSettings(
        demoTopUpCoins: 50,
        catalogFreeEpisodes: 3,
        catalogPriceCoins: 12,
      );
      final back = AdminSettings.fromJson(s.toJson());
      expect(back.demoTopUpCoins, 50);
      expect(back.catalogFreeEpisodes, 3);
      expect(back.catalogPriceCoins, 12);

      final empty = AdminSettings.fromJson({});
      expect(empty.catalogFreeEpisodes, 5);
      expect(empty.catalogPriceCoins, 10);
    });

    test('AdminCoinPack and FilmSales read numbers of any kind', () {
      final pack = AdminCoinPack.fromJson({
        'id': 1,
        'name': 'Starter',
        'coins': 60,
        'price_usd': 1,
        'sold_count': 3,
      });
      expect(pack.priceUsd, 1.0);
      final sales = FilmSales.fromJson({
        'film_id': 1,
        'title': 'A',
        'unlock_count': 2,
        'coins_spent': 40,
      });
      expect(sales.coinsSpent, 40);
    });
  });

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
}
