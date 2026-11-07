import 'dart:async';

import 'package:shortreel/data/app_repository.dart';
import 'package:shortreel/models/coin_pack.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/models/transaction.dart';
import 'package:shortreel/models/user.dart';

/// A stand-in for [AppRepository] in controller tests. Only the calls the
/// controllers under test make are answered; anything else fails the test, so a
/// controller cannot quietly start depending on something new.
///
/// Each answer can be swapped per test, and [calls] records what was asked.
class FakeRepository implements AppRepository {
  final List<String> calls = [];

  // ---- people ----
  User viewer = const User(
    id: 2,
    username: 'viewer01',
    displayName: 'Viewer',
    role: UserRole.viewer,
    coinBalance: 80,
  );
  Object? loginError;
  Completer<User>? loginGate;

  @override
  Future<User> login(String username, String password) async {
    calls.add('login $username');
    if (loginError != null) throw loginError!;
    if (loginGate != null) return loginGate!.future;
    return viewer;
  }

  @override
  Future<User> register(String username, String password) async {
    calls.add('register $username');
    return viewer.copyWith(displayName: username);
  }

  User? stored;

  @override
  Future<User?> restoreSession() async {
    calls.add('restoreSession');
    return stored;
  }

  bool logoutFails = false;

  @override
  Future<void> logout() async {
    calls.add('logout');
    if (logoutFails) throw Exception('offline');
  }

  @override
  Future<void> clearSession() async => calls.add('clearSession');

  @override
  Future<User> updateProfile(
    int userId, {
    required String displayName,
    required String bio,
  }) async {
    calls.add('updateProfile $userId');
    return viewer.copyWith(displayName: displayName, bio: bio);
  }

  // ---- wallet ----
  List<Transaction> transactions = const [];
  List<CoinPack> packs = const [
    CoinPack(id: 1, name: 'Starter', coins: 60, priceUsd: 0.99),
  ];
  Object? walletError;

  @override
  Future<List<Transaction>> transactionsOf(int userId) async {
    calls.add('transactionsOf $userId');
    if (walletError != null) throw walletError!;
    return transactions;
  }

  @override
  Future<List<CoinPack>> coinPacks() async => packs;

  @override
  Future<User> refreshBalance(int userId) async => viewer;

  @override
  Future<User> demoTopUp(int userId) async {
    calls.add('demoTopUp');
    viewer = viewer.copyWith(coinBalance: viewer.coinBalance + demoTopUpCoins);
    return viewer;
  }

  @override
  Future<User> topUpPack(int userId, CoinPack pack) async {
    calls.add('topUpPack ${pack.id}');
    viewer = viewer.copyWith(coinBalance: viewer.coinBalance + pack.coins);
    return viewer;
  }

  Object? unlockError;

  @override
  Future<User> unlock(int userId, int episodeId) async {
    calls.add('unlock $episodeId');
    if (unlockError != null) throw unlockError!;
    viewer = viewer.copyWith(coinBalance: viewer.coinBalance - 20);
    return viewer;
  }

  @override
  int get demoTopUpCoins => 100;

  @override
  int get episodePriceCoins => 20;

  // ---- films ----
  List<Film> filmList = const [];
  Object? filmsError;
  final Map<String, Completer<List<Film>>> filmGates = {};

  @override
  Future<List<Film>> films([String query = '']) async {
    calls.add('films $query');
    if (filmsError != null) throw filmsError!;
    final gate = filmGates[query];
    if (gate != null) return gate.future;
    return filmList
        .where((f) => f.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // ---- admin ----
  AdminSales sales = const AdminSales(totalUsd: 4.99, coinsSpent: 80);
  List<AdminFilm> adminFilmList = const [];
  List<AdminComment> commentList = const [];
  AdminSettings settings = const AdminSettings();
  List<AdminCoinPack> adminPacks = const [];
  Object? adminError;

  @override
  Future<AdminSales> adminSales() async {
    if (adminError != null) throw adminError!;
    return sales;
  }

  @override
  Future<List<AdminFilm>> adminFilms() async {
    if (adminError != null) throw adminError!;
    return adminFilmList;
  }

  @override
  Future<void> adminSetFilmTakenDown(int filmId, bool takenDown) async {
    calls.add('setTakenDown $filmId $takenDown');
    if (adminError != null) throw adminError!;
  }

  @override
  Future<List<AdminComment>> adminComments() async {
    if (adminError != null) throw adminError!;
    return commentList;
  }

  @override
  Future<void> adminDeleteComment(int commentId) async {
    calls.add('deleteComment $commentId');
    if (adminError != null) throw adminError!;
  }

  @override
  Future<AdminSettings> adminSettings() async {
    if (adminError != null) throw adminError!;
    return settings;
  }

  @override
  Future<AdminSettings> adminSaveSettings(AdminSettings value) async {
    calls.add('saveSettings');
    settings = value;
    return value;
  }

  @override
  Future<List<AdminCoinPack>> adminCoinPacks() async => adminPacks;

  @override
  Future<void> adminSaveCoinPack({
    int? id,
    required String name,
    required int coins,
    required double priceUsd,
  }) async {
    calls.add('saveCoinPack ${id ?? 'new'} $name');
    adminPacks = [
      ...adminPacks.where((p) => p.id != id),
      AdminCoinPack(
        id: id ?? 99,
        name: name,
        coins: coins,
        priceUsd: priceUsd,
        soldCount: 0,
      ),
    ];
  }

  @override
  Future<void> adminDeleteCoinPack(int id) async {
    calls.add('deleteCoinPack $id');
    if (adminError != null) throw adminError!;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeRepository does not answer ${invocation.memberName}',
  );
}
