// Person 4: WalletController (balance, top-up, unlocking).
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'package:shortreel/controllers/wallet_controller.dart';
import 'package:shortreel/services/api_client.dart';

import '../support/fake_repository.dart';
import '../support/helpers.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

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

  test('WalletController shows the prices the repository sets', () async {
    final auth = AuthController(repo);
    final wallet = WalletController(repo, auth);
    expect(wallet.balance, 0);
    expect(wallet.episodePrice, 20);
    expect(wallet.demoTopUpCoins, 100);
    wallet.dispose();
  });
}
