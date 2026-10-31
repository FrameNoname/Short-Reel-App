import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/coin_pack.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import 'auth_controller.dart';

class WalletController extends ChangeNotifier {
  WalletController(this.repository, this._auth);

  final AppRepository repository;
  final AuthController _auth;

  int get _userId => _auth.user!.id;

  int get balance => _auth.user?.coinBalance ?? 0;

  int get episodePrice => repository.episodePriceCoins;

  String get planPrice =>
      '\$${repository.subscriptionPriceUsd.toStringAsFixed(2)}';

  List<CoinPack> get coinPacks => repository.coinPacks();

  List<Transaction> get transactions => repository.transactionsOf(_userId);

  Subscription? get subscription => repository.subscriptionOf(_userId);

  Future<void> demoTopUp() => buy(coins: repository.demoTopUpCoins);

  Future<void> buy({required int coins, double priceUsd = 0}) async {
    final user = await repository.topUp(
      _userId,
      coins: coins,
      priceUsd: priceUsd,
    );
    _auth.updateUser(user);
    notifyListeners();
  }

  Future<void> unlock(int episodeId) async {
    _auth.updateUser(await repository.unlock(_userId, episodeId));
    notifyListeners();
  }

  void cancelPlan() {
    repository.cancelSubscription(_userId);
    notifyListeners();
  }

  Future<void> subscribe() async {
    await repository.subscribe(_userId);
    notifyListeners();
  }
}
