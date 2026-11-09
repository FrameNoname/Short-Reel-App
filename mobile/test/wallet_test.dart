// Person 4: wallet, coin packs and unlocking.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'package:shortreel/controllers/wallet_controller.dart';
import 'package:shortreel/models/coin_pack.dart';
import 'package:shortreel/models/transaction.dart';
import 'package:shortreel/services/api_client.dart';

import 'support/fake_repository.dart';
import 'support/helpers.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

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

  group('WalletController', () {
    late AuthController auth;
    late WalletController wallet;

    setUp(() async {
      auth = AuthController(repo);
      await auth.login('viewer01', '6666');
      wallet = WalletController(repo, auth);
    });

    test('load reads the history and packs', () async {
      await wallet.load();
      expect(wallet.coinPacks.single.name, 'Starter');
      expect(wallet.error, isNull);
      expect(wallet.isLoading, isFalse);
    });

    test('load shows the error when the server fails', () async {
      repo.walletError = serverDown;
      await wallet.load();
      expect(wallet.error, 'Cannot reach the server');
    });

    test('a demo top-up and a pack add coins to the balance', () async {
      await wallet.demoTopUp();
      expect(wallet.balance, 180);
      await wallet.buy(repo.packs.single);
      expect(wallet.balance, 240);
      expect(repo.calls, containsAll(['demoTopUp', 'topUpPack 1']));
    });

    test(
      'unlock spends coins, and a refused unlock reaches the caller',
      () async {
        await wallet.unlock(9);
        expect(wallet.balance, 60);

        repo.unlockError = const ApiException(
          code: 'INSUFFICIENT_COINS',
          message: 'Not enough coins',
          statusCode: 402,
        );
        await expectLater(wallet.unlock(9), throwsA(isA<ApiException>()));
        expect(wallet.balance, 60);
      },
    );

    test('logging out drops what was loaded', () async {
      await wallet.load();
      await auth.logout();
      expect(wallet.transactions, isEmpty);
      expect(wallet.balance, 0);
    });
  });
}
