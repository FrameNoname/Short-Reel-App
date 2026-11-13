// Person 6: the admin models.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/app_repository.dart';

void main() {
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

    test('AdminEpisode reads the API shape and copyWith sets the price', () {
      final episode = AdminEpisode.fromJson({
        'id': 7,
        'episode_no': 3,
        'title': null,
        'is_free': false,
        'price_coins': 20,
        'unlock_count': 2,
      });
      expect(episode.id, 7);
      expect(episode.isFree, isFalse);
      expect(episode.unlockCount, 2);
      final free = episode.copyWith(isFree: true, priceCoins: 0);
      expect(free.isFree, isTrue);
      expect(free.episodeNo, 3);
    });

    test('AdminComment reads the film title and time', () {
      final comment = AdminComment.fromJson({
        'id': 4,
        'body': 'Nice',
        'username': 'mira.lens',
        'film_title': 'Paper Moons',
        'created_at': '2026-11-08T10:00:00Z',
      });
      expect(comment.filmTitle, 'Paper Moons');
      expect(comment.createdAt.toUtc(), DateTime.utc(2026, 11, 8, 10));
    });

    test('sameAs matches a series by drama id and a film by id', () {
      AdminFilm row(int id, int? drama) => AdminFilm(
        id: id,
        title: 'x',
        posterUrl: null,
        takenDown: false,
        episodeCount: 0,
        likeCount: 0,
        commentCount: 0,
        coinsSpent: 0,
        catalogDramaId: drama,
      );
      expect(row(0, 21).sameAs(row(6, 21)), isTrue);
      expect(row(6, 21).sameAs(row(6, null)), isFalse);
      expect(row(6, null).sameAs(row(6, null)), isTrue);
      expect(row(6, null).sameAs(row(6, 21)), isFalse);
    });
  });
}
