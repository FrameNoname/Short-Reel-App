import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/coin_pack.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../services/errors.dart';
import 'auth_controller.dart';

class WalletController extends ChangeNotifier {
  WalletController(this.repository, this._auth) {
    _auth.addListener(_followLogin);
  }

  final AppRepository repository;
  final AuthController _auth;

  List<Transaction> transactions = const [];
  List<CoinPack> coinPacks = const [];
  Subscription? subscription;
  bool isLoading = false;
  String? error;
  int? _loadedFor;

  int get _userId => _auth.user!.id;

  int get balance => _auth.user?.coinBalance ?? 0;

  /// A typical episode price, only used for "= N episodes" hints.
  int get episodePrice => repository.episodePriceCoins;

  int get demoTopUpCoins => repository.demoTopUpCoins;

  String get planPrice =>
      '\$${repository.subscriptionPriceUsd.toStringAsFixed(2)}';

  /// Another person logged in (or out): drop what belonged to the last one.
  void _followLogin() {
    if (_auth.user?.id == _loadedFor) return;
    reset();
  }

  void reset() {
    transactions = const [];
    subscription = null;
    error = null;
    _loadedFor = null;
    notifyListeners();
  }

  /// Reads the balance history, the packs and the plan from the backend.
  Future<void> load() async {
    if (!_auth.isLoggedIn) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final id = _userId;
      final results = await Future.wait<Object?>([
        repository.transactionsOf(id),
        repository.coinPacks(),
        repository.subscriptionOf(id),
      ]);
      transactions = results[0]! as List<Transaction>;
      coinPacks = results[1]! as List<CoinPack>;
      subscription = results[2] as Subscription?;
      _loadedFor = id;
    } on Object catch (e) {
      error = errorMessage(e);
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> demoTopUp() async {
    _auth.updateUser(await repository.demoTopUp(_userId));
    await load();
  }

  Future<void> buy(CoinPack pack) async {
    _auth.updateUser(await repository.topUpPack(_userId, pack));
    await load();
  }

  Future<void> unlock(int episodeId) async {
    _auth.updateUser(await repository.unlock(_userId, episodeId));
    await load();
  }

  Future<void> cancelPlan() async {
    await repository.cancelSubscription(_userId);
    await load();
  }

  Future<void> subscribe() async {
    await repository.subscribe(_userId);
    await load();
  }

  @override
  void dispose() {
    _auth.removeListener(_followLogin);
    super.dispose();
  }
}
