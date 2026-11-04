import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/coin_pack.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/api_client.dart' show isStaleSession;
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
  bool isLoading = false;
  String? error;
  int? _loadedFor;
  int _request = 0;

  int get _userId => _auth.user!.id;

  int get balance => _auth.user?.coinBalance ?? 0;

  /// A typical episode price, only used for "= N episodes" hints.
  int get episodePrice => repository.episodePriceCoins;

  int get demoTopUpCoins => repository.demoTopUpCoins;

  /// Another person logged in (or out): drop what belonged to the last one.
  void _followLogin() {
    if (_auth.user?.id == _loadedFor) return;
    reset();
  }

  void reset() {
    _request++;
    isLoading = false;
    transactions = const [];
    error = null;
    _loadedFor = null;
    notifyListeners();
  }

  /// Reads the balance history and the packs from the backend.
  Future<void> load() async {
    if (!_auth.isLoggedIn) return;
    final id = _userId;
    final request = ++_request;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        repository.transactionsOf(id),
        repository.coinPacks(),
        // The balance is read from the server too: it may have changed from
        // another device since this person logged in.
        repository.refreshBalance(id),
      ]);
      // Another person logged in, or a newer load started: this answer is old.
      if (request != _request || _auth.user?.id != id) return;
      transactions = results[0]! as List<Transaction>;
      coinPacks = results[1]! as List<CoinPack>;
      // Before the balance is applied: that notifies auth, and a listener that
      // sees an unloaded user would reset what was just read.
      _loadedFor = id;
      _auth.updateUser(results[2]! as User);
    } on Object catch (e) {
      if (request != _request || isStaleSession(e)) return;
      error = errorMessage(e);
    }
    isLoading = false;
    notifyListeners();
  }

  /// Runs one wallet action. If the person logged out (or another logged in)
  /// while it was in flight, its answer is dropped without an error.
  Future<void> _act(Future<void> Function(int userId) body) async {
    final id = _userId;
    try {
      await body(id);
    } on Object catch (e) {
      if (isStaleSession(e)) return;
      rethrow;
    }
    if (_auth.user?.id == id) await load();
  }

  Future<void> demoTopUp() =>
      _act((id) async => _auth.updateUser(await repository.demoTopUp(id)));

  Future<void> buy(CoinPack pack) => _act(
    (id) async => _auth.updateUser(await repository.topUpPack(id, pack)),
  );

  Future<void> unlock(int episodeId) => _act(
    (id) async => _auth.updateUser(await repository.unlock(id, episodeId)),
  );

  @override
  void dispose() {
    _auth.removeListener(_followLogin);
    super.dispose();
  }
}
