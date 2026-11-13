// Person 4: the CoinPack model and CoinPackOffers.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/models/coin_pack.dart';

void main() {
  group('CoinPack', () {
    test('reads a price sent as text or a number', () {
      final pack = CoinPack.fromJson({
        'id': 2,
        'name': 'Popular',
        'coins': 330,
        'price_usd': '4.99',
      });
      expect(pack.priceUsd, 4.99);
      expect(
        CoinPack.fromJson({
          'id': 1,
          'name': 'Starter',
          'coins': 60,
          'price_usd': 1,
        }).priceUsd,
        1.0,
      );
    });
  });

  group('CoinPackOffers', () {
    const starter = CoinPack(id: 1, name: 'Starter', coins: 60, priceUsd: 0.99);
    const popular = CoinPack(
      id: 2,
      name: 'Popular',
      coins: 330,
      priceUsd: 4.99,
    );
    const big = CoinPack(id: 3, name: 'Big', coins: 750, priceUsd: 9.99);

    test('bonus is measured against the cheapest pack per whole dollar', () {
      final offers = CoinPackOffers([starter, popular, big]);
      expect(offers.bonusOf(starter), 0);
      expect(offers.bonusOf(popular), 30);
      expect(offers.bonusOf(big), 150);
    });

    test('best value is the most coins per dollar', () {
      expect(CoinPackOffers([starter, popular, big]).bestValue, big);
    });

    test('an edited pack is described from its own numbers', () {
      const edited = CoinPack(id: 3, name: 'Big', coins: 1000, priceUsd: 9.99);
      final offers = CoinPackOffers([starter, popular, edited]);
      expect(offers.bonusOf(edited), 400);
      expect(offers.bestValue, edited);
    });

    test('no bonus or badge when every pack has the same rate', () {
      const a = CoinPack(id: 1, name: 'A', coins: 100, priceUsd: 1);
      const b = CoinPack(id: 2, name: 'B', coins: 500, priceUsd: 5);
      final offers = CoinPackOffers([a, b]);
      expect(offers.bonusOf(b), 0);
      expect(offers.bestValue, isNull);
      expect(CoinPackOffers(const []).bestValue, isNull);
    });
  });
}
