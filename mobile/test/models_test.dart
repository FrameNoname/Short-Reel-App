import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/app_repository.dart';
import 'package:shortreel/models/episode.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/models/transaction.dart';
import 'package:shortreel/models/user.dart';

void main() {
  group('User', () {
    test('reads the API shape and marks only admins as verified', () {
      final user = User.fromJson({
        'id': 1,
        'username': 'admin',
        'display_name': null,
        'role': 'admin',
        'coin_balance': 0,
      });
      expect(user.role, UserRole.admin);
      expect(user.isVerified, isTrue);
      expect(user.copyWith(coinBalance: 5).isVerified, isTrue);

      final viewer = User.fromJson({
        'id': 2,
        'username': 'v',
        'role': 'viewer',
        'coin_balance': 80,
        'bio': 'hi',
      });
      expect(viewer.isVerified, isFalse);
      expect(viewer.bio, 'hi');
    });

    test('copyWith keeps what it is not given', () {
      const user = User(
        id: 1,
        username: 'a',
        displayName: 'A',
        role: UserRole.viewer,
        coinBalance: 10,
        bio: 'b',
      );
      final updated = user.copyWith(coinBalance: 30);
      expect(updated.coinBalance, 30);
      expect(updated.displayName, 'A');
      expect(updated.bio, 'b');
    });
  });

  group('Episode', () {
    test('maps every API access value', () {
      Episode withAccess(String? access) => Episode.fromJson({
        'id': 1,
        'film_id': 1,
        'episode_no': 1,
        'title': null,
        'duration_sec': 60,
        'is_free': false,
        'price_coins': 20,
        'access': access,
      });
      expect(withAccess('free').access, EpisodeAccess.free);
      expect(withAccess('owner').access, EpisodeAccess.unlocked);
      expect(withAccess('unlocked').access, EpisodeAccess.unlocked);
      expect(withAccess('locked').access, EpisodeAccess.locked);
      expect(withAccess('login_required').access, EpisodeAccess.locked);
      expect(withAccess(null).access, isNull);
    });

    test('reads is_free as a bool or 0/1 and withPrice(0) makes it free', () {
      final e = Episode.fromJson({
        'id': 1,
        'film_id': 1,
        'episode_no': 2,
        'duration_sec': 60,
        'is_free': 1,
        'price_coins': 0,
      });
      expect(e.isFree, isTrue);
      expect(e.withPrice(15).isFree, isFalse);
      expect(e.withPrice(15).priceCoins, 15);
      expect(e.withPrice(0).isFree, isTrue);
    });
  });

  test('Film reads counts with defaults and copyWith keeps the rest', () {
    final film = Film.fromJson({
      'id': 3,
      'title': 'Salt & Signal',
      'genre_id': 1,
      'ai_tool_id': 2,
      'is_ai_generated': true,
      'status': 'approved',
      'like_count': 4,
    });
    expect(film.likeCount, 4);
    expect(film.commentCount, 0);
    expect(film.genreName, '');
    final liked = film.copyWith(likeCount: 5);
    expect(liked.likeCount, 5);
    expect(liked.title, 'Salt & Signal');
  });

  group('Transaction labels', () {
    Transaction read(Map<String, dynamic> extra) => Transaction.fromJson({
      'id': 1,
      'amount': 10,
      'balance_after': 10,
      'created_at': '2026-11-08T10:00:00Z',
      ...extra,
    });

    test('an unlock names the film and episode', () {
      final t = read({
        'type': 'unlock',
        'film_title': 'Ember',
        'episode_no': 3,
        'price_usd': null,
      });
      expect(t.label, 'Ember, Episode 3');
      expect(t.priceUsd, isNull);
    });

    test('a pack top-up names the pack and keeps its price', () {
      final t = read({
        'type': 'topup',
        'pack_name': 'Starter',
        'price_usd': '0.99',
      });
      expect(t.label, 'Starter pack');
      expect(t.priceUsd, 0.99);
    });

    test('a top-up without a pack is the demo one', () {
      expect(read({'type': 'topup'}).label, 'Demo top-up');
    });
  });

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
}
