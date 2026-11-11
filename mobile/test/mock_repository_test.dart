// Person 3: the demo data behind this build (MockRepository).
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/app_repository.dart';
import 'package:shortreel/data/mock_repository.dart';

/// The front-end-only build answers from [MockRepository]; these tests make
/// sure it follows the same rules as the server.
void main() {
  late MockRepository repo;

  setUp(() => repo = MockRepository(now: DateTime(2026, 11, 8)));

  test('a taken-down film disappears from the feed and comes back', () async {
    final film = (await repo.adminFilms()).first;
    await repo.adminSetFilmTakenDown(film, true);
    expect((await repo.films()).map((f) => f.id), isNot(contains(film.id)));
    expect((await repo.adminFilms()).first.takenDown, isTrue);

    await repo.adminSetFilmTakenDown(film, false);
    expect((await repo.films()).map((f) => f.id), contains(film.id));
  });

  test('a new episode price is what viewers pay', () async {
    final film = (await repo.adminFilms()).first;
    final paid = (await repo.adminEpisodes(
      film.id,
    )).firstWhere((e) => !e.isFree);
    await repo.adminUpdateEpisode(paid, isFree: false, priceCoins: 7);
    final episode = (await repo.episodes(
      film.id,
    )).firstWhere((e) => e.id == paid.id);
    expect(episode.priceCoins, 7);

    await repo.adminUpdateEpisode(paid, isFree: true, priceCoins: 0);
    final free = (await repo.episodes(
      film.id,
    )).firstWhere((e) => e.id == paid.id);
    expect(free.isFree, isTrue);

    await expectLater(
      repo.adminUpdateEpisode(paid, isFree: false, priceCoins: 0),
      throwsA(anything),
    );
  });

  test('deleting a comment from the admin removes it from the film', () async {
    final comment = (await repo.adminComments()).first;
    final before = repo.commentsOf(1).length + repo.commentsOf(2).length;
    await repo.adminDeleteComment(comment.id);
    expect(await repo.adminComments(), hasLength(1));
    expect(repo.commentsOf(1).length + repo.commentsOf(2).length, before - 1);
  });

  test('the demo top-up follows the setting', () async {
    await repo.adminSaveSettings(const AdminSettings(demoTopUpCoins: 250));
    expect(repo.demoTopUpCoins, 250);
    expect((await repo.adminSettings()).demoTopUpCoins, 250);
  });

  test('coin packs can be added, edited and deleted unless bought', () async {
    await repo.adminSaveCoinPack(name: 'Mega', coins: 2000, priceUsd: 19.99);
    var packs = await repo.adminCoinPacks();
    final mega = packs.firstWhere((p) => p.name == 'Mega');
    expect((await repo.coinPacks()).map((p) => p.name), contains('Mega'));

    await repo.adminSaveCoinPack(
      id: mega.id,
      name: 'Mega+',
      coins: 2500,
      priceUsd: 19.99,
    );
    packs = await repo.adminCoinPacks();
    expect(packs.firstWhere((p) => p.id == mega.id).coins, 2500);

    await repo.adminDeleteCoinPack(mega.id);
    expect((await repo.coinPacks()).map((p) => p.id), isNot(contains(mega.id)));

    final sold = packs.firstWhere((p) => p.soldCount > 0);
    await expectLater(repo.adminDeleteCoinPack(sold.id), throwsA(anything));
  });

  test('sales list the best-selling films first', () async {
    final sales = await repo.adminSales();
    expect(sales.perFilm, isNotEmpty);
    final coins = sales.perFilm.map((f) => f.coinsSpent).toList();
    expect(coins, [...coins]..sort((a, b) => b.compareTo(a)));
    expect(coins.fold(0, (a, b) => a + b), sales.coinsSpent);
  });

  group('Series Jeen catalog', () {
    test('the feed lists 12 series after the app films', () async {
      final films = await repo.films();
      final catalog = films.where((f) => f.catalogDramaId != null).toList();
      expect(catalog, hasLength(12));
      expect(films.indexOf(catalog.first), films.length - 12);
      expect(catalog.every((f) => f.posterUrl != null), isTrue);
    });

    test('episode 6 costs 10 coins once; the admin never pays', () async {
      await repo.login('viewer01', '6666');
      final film = (await repo.films()).firstWhere(
        (f) => f.catalogDramaId != null,
      );
      expect(repo.catalogEpisodeLocked(film, 5), isFalse);
      expect(repo.catalogEpisodeLocked(film, 6), isTrue);

      final episode = (await repo.episodes(film.id))[5];
      final user = await repo.unlock(3, episode.id);
      expect(user.coinBalance, 70);
      expect(repo.catalogEpisodeLocked(film, 6), isFalse);
      expect((await repo.unlock(3, episode.id)).coinBalance, 70);
      expect((await repo.transactionsOf(3)).first.amount, -10);
      expect(
        (await repo.adminFilms()).first.catalogDramaId,
        film.catalogDramaId,
      );

      await repo.login('admin', '1111');
      expect(repo.catalogEpisodeLocked(film, 50), isFalse);
    });

    test(
      'a series the admin takes down leaves the feed and the list',
      () async {
        final found = await repo.adminSearchCatalog('เหยื่อ');
        expect(found, isNotEmpty);
        expect(found.first.id, 0);
        final drama = found.first.catalogDramaId!;

        await repo.adminSetFilmTakenDown(found.first, true);
        expect(
          (await repo.films()).map((f) => f.catalogDramaId),
          isNot(contains(drama)),
        );
        expect(repo.catalogDramas.map((d) => d.id), isNot(contains(drama)));
        expect((await repo.adminFilms()).first.takenDown, isTrue);

        await repo.adminSetFilmTakenDown(found.first, false);
        expect(repo.catalogDramas.map((d) => d.id), contains(drama));
      },
    );
  });
}
