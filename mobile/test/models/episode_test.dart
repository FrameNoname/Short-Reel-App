// Person 2: the Episode model.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/models/episode.dart';

void main() {
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
}
