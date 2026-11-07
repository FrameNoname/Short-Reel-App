import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/admin_controller.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'package:shortreel/controllers/film_search_controller.dart';
import 'package:shortreel/controllers/wallet_controller.dart';
import 'package:shortreel/data/app_repository.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/models/user.dart';
import 'package:shortreel/services/api_client.dart';

import 'support/fake_repository.dart';

const _serverDown = ApiException(
  code: 'NETWORK',
  message: 'Cannot reach the server',
);

Film _film(int id, String title, {int likes = 0}) => Film(
  id: id,
  title: title,
  synopsis: null,
  posterUrl: null,
  genreId: 1,
  aiToolId: 1,
  promptCredit: null,
  isAiGenerated: true,
  status: 'approved',
  likeCount: likes,
);

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

  group('AuthController', () {
    test('login signs the person in and notifies', () async {
      final auth = AuthController(repo);
      var notified = 0;
      auth.addListener(() => notified++);

      await auth.login('viewer01', '6666');

      expect(auth.isLoggedIn, isTrue);
      expect(auth.role, UserRole.viewer);
      expect(auth.hasEntered, isTrue);
      expect(notified, greaterThan(0));
    });

    test('a failed login leaves nobody signed in', () async {
      repo.loginError = _serverDown;
      final auth = AuthController(repo);
      await expectLater(auth.login('viewer01', 'x'), throwsA(_serverDown));
      expect(auth.isLoggedIn, isFalse);
      expect(auth.role, UserRole.guest);
    });

    test('a guest has entered but is not logged in', () {
      final auth = AuthController(repo)..continueAsGuest();
      expect(auth.hasEntered, isTrue);
      expect(auth.isLoggedIn, isFalse);
    });

    test('logout clears the user and runs the logout listeners even offline', () async {
      repo.logoutFails = true;
      final auth = AuthController(repo);
      var cleaned = false;
      auth.addLogoutListener(() => cleaned = true);
      await auth.login('viewer01', '6666');

      await auth.logout();

      expect(auth.user, isNull);
      expect(cleaned, isTrue);
      expect(auth.hasEntered, isFalse);
    });

    test('a login that finishes after logout is dropped', () async {
      repo.loginGate = Completer<User>();
      final auth = AuthController(repo);
      final pending = auth.login('viewer01', '6666');
      await auth.logout();
      repo.loginGate!.complete(repo.viewer);
      await pending;
      expect(auth.isLoggedIn, isFalse);
    });

    test('restoreSession signs in from the stored token', () async {
      repo.stored = repo.viewer;
      final auth = AuthController(repo);
      await auth.restoreSession();
      expect(auth.user?.id, repo.viewer.id);
      expect(auth.isRestoring, isFalse);
    });

    test('updateUser ignores a copy of someone else', () async {
      final auth = AuthController(repo);
      await auth.login('viewer01', '6666');
      auth.updateUser(
        const User(
          id: 999,
          username: 'other',
          displayName: null,
          role: UserRole.viewer,
          coinBalance: 1,
        ),
      );
      expect(auth.user!.id, repo.viewer.id);
      auth.updateUser(repo.viewer.copyWith(coinBalance: 5));
      expect(auth.user!.coinBalance, 5);
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
      repo.walletError = _serverDown;
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

    test('unlock spends coins, and a refused unlock reaches the caller', () async {
      await wallet.unlock(9);
      expect(wallet.balance, 60);

      repo.unlockError = const ApiException(
        code: 'INSUFFICIENT_COINS',
        message: 'Not enough coins',
        statusCode: 402,
      );
      await expectLater(wallet.unlock(9), throwsA(isA<ApiException>()));
      expect(wallet.balance, 60);
    });

    test('logging out drops what was loaded', () async {
      await wallet.load();
      await auth.logout();
      expect(wallet.transactions, isEmpty);
      expect(wallet.balance, 0);
    });
  });

  group('FilmSearchController', () {
    test('apply finds films by title', () async {
      repo.filmList = [_film(1, 'Salt & Signal'), _film(2, 'Paper Moons')];
      final search = FilmSearchController(repo);
      await search.apply('paper');
      expect(search.results.map((f) => f.title), ['Paper Moons']);
      expect(search.error, isNull);
    });

    test('a slow answer for an old word does not replace the newer one', () async {
      repo.filmList = [_film(1, 'Salt & Signal'), _film(2, 'Paper Moons')];
      repo.filmGates['s'] = Completer<List<Film>>();
      final search = FilmSearchController(repo);

      final old = search.apply('s');
      await search.apply('paper');
      repo.filmGates['s']!.complete([_film(1, 'Salt & Signal')]);
      await old;

      expect(search.query, 'paper');
      expect(search.results.map((f) => f.title), ['Paper Moons']);
    });

    test('a failed search clears the results and shows why', () async {
      repo.filmsError = _serverDown;
      final search = FilmSearchController(repo);
      await search.apply('x');
      expect(search.results, isEmpty);
      expect(search.error, 'Cannot reach the server');
    });

    test('trending is the five most liked films', () async {
      repo.filmList = [
        for (var i = 1; i <= 7; i++) _film(i, 'Film $i', likes: i),
      ];
      final search = FilmSearchController(repo);
      await search.loadTrending();
      expect(search.trending.map((f) => f.id), [7, 6, 5, 4, 3]);
    });

    test('recent searches stay unique, newest first, at most eight', () {
      final search = FilmSearchController(repo);
      for (var i = 0; i < 10; i++) {
        search.remember('word $i');
      }
      search.remember('WORD 5');
      search.remember('   ');
      expect(search.recent.length, 8);
      expect(search.recent.first, 'WORD 5');
      expect(search.recent.where((t) => t.toLowerCase() == 'word 5').length, 1);

      search.forget('WORD 5');
      expect(search.recent, isNot(contains('WORD 5')));
      search.clearRecent();
      expect(search.recent, isEmpty);
    });
  });

  group('AdminController', () {
    const film = AdminFilm(
      id: 1,
      title: 'Salt & Signal',
      posterUrl: null,
      takenDown: false,
      episodeCount: 8,
      likeCount: 1,
      commentCount: 1,
      coinsSpent: 40,
    );

    test('load reads the sales or keeps the error', () async {
      final admin = AdminController(repo);
      await admin.load();
      expect(admin.sales.totalUsd, 4.99);
      expect(admin.error, isNull);

      repo.adminError = _serverDown;
      await admin.load();
      expect(admin.error, 'Cannot reach the server');
      expect(admin.isLoading, isFalse);
    });

    test('taking a film down updates the list in place', () async {
      repo.adminFilmList = [film];
      final admin = AdminController(repo);
      await admin.loadFilms();

      await admin.setTakenDown(film, true);

      expect(repo.calls, contains('setTakenDown 1 true'));
      expect(admin.films.single.takenDown, isTrue);
    });

    test('a failed take-down leaves the list as it was', () async {
      repo.adminFilmList = [film];
      final admin = AdminController(repo);
      await admin.loadFilms();
      repo.adminError = _serverDown;

      await expectLater(admin.setTakenDown(film, true), throwsA(_serverDown));
      expect(admin.films.single.takenDown, isFalse);
    });

    test('deleting a comment removes only that one', () async {
      final now = DateTime(2026, 11, 8);
      repo.commentList = [
        AdminComment(
          id: 1,
          body: 'a',
          username: 'u',
          filmTitle: 'F',
          createdAt: now,
        ),
        AdminComment(
          id: 2,
          body: 'b',
          username: 'u',
          filmTitle: 'F',
          createdAt: now,
        ),
      ];
      final admin = AdminController(repo);
      await admin.loadComments();
      await admin.deleteComment(admin.comments.first);
      expect(admin.comments.map((c) => c.id), [2]);
    });

    test('settings and coin packs load together and save', () async {
      repo.adminPacks = const [
        AdminCoinPack(
          id: 1,
          name: 'Starter',
          coins: 60,
          priceUsd: 0.99,
          soldCount: 2,
        ),
      ];
      final admin = AdminController(repo);
      await admin.loadSettings();
      expect(admin.coinPacks.single.name, 'Starter');

      await admin.saveSettings(const AdminSettings(catalogPriceCoins: 15));
      expect(admin.settings.catalogPriceCoins, 15);

      await admin.saveCoinPack(name: 'Mega', coins: 999, priceUsd: 9.99);
      expect(admin.coinPacks.map((p) => p.name), ['Starter', 'Mega']);

      await admin.deleteCoinPack(admin.coinPacks.first);
      expect(admin.coinPacks.map((p) => p.name), ['Mega']);
    });

    test('reset forgets everything', () async {
      repo.adminFilmList = [film];
      final admin = AdminController(repo);
      await admin.load();
      await admin.loadFilms();
      admin.reset();
      expect(admin.films, isEmpty);
      expect(admin.sales.totalUsd, 0);
    });
  });
}
