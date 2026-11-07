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
    await repo.adminSetFilmTakenDown(film.id, true);
    expect((await repo.films()).map((f) => f.id), isNot(contains(film.id)));
    expect((await repo.adminFilms()).first.takenDown, isTrue);

    await repo.adminSetFilmTakenDown(film.id, false);
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
}
