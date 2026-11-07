import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../services/errors.dart';

/// State for the admin tab and the screens it opens: sales, films, comments,
/// settings and coin packs. Actions throw so the screen can show the message.
class AdminController extends ChangeNotifier {
  AdminController(this._repository);

  final AppRepository _repository;

  AdminSales sales = const AdminSales(totalUsd: 0);
  bool isLoading = false;
  String? error;

  List<AdminFilm> films = const [];
  bool filmsLoading = false;
  String? filmsError;

  List<AdminComment> comments = const [];
  bool commentsLoading = false;
  String? commentsError;

  AdminSettings settings = const AdminSettings();
  List<AdminCoinPack> coinPacks = const [];
  bool settingsLoading = false;
  String? settingsError;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      sales = await _repository.adminSales();
    } on Object catch (e) {
      error = errorMessage(e);
    }
    isLoading = false;
    notifyListeners();
  }

  // ---- films ----

  Future<void> loadFilms() async {
    filmsLoading = true;
    filmsError = null;
    notifyListeners();
    try {
      films = await _repository.adminFilms();
    } on Object catch (e) {
      filmsError = errorMessage(e);
    }
    filmsLoading = false;
    notifyListeners();
  }

  Future<void> setTakenDown(AdminFilm film, bool takenDown) async {
    await _repository.adminSetFilmTakenDown(film.id, takenDown);
    films = [
      for (final f in films) f.id == film.id ? f.withTakenDown(takenDown) : f,
    ];
    notifyListeners();
  }

  Future<List<AdminEpisode>> episodesOf(int filmId) =>
      _repository.adminEpisodes(filmId);

  Future<AdminEpisode> updateEpisode(
    AdminEpisode episode, {
    required bool isFree,
    required int priceCoins,
  }) => _repository.adminUpdateEpisode(
    episode,
    isFree: isFree,
    priceCoins: priceCoins,
  );

  // ---- comments ----

  Future<void> loadComments() async {
    commentsLoading = true;
    commentsError = null;
    notifyListeners();
    try {
      comments = await _repository.adminComments();
    } on Object catch (e) {
      commentsError = errorMessage(e);
    }
    commentsLoading = false;
    notifyListeners();
  }

  Future<void> deleteComment(AdminComment comment) async {
    await _repository.adminDeleteComment(comment.id);
    comments = [
      for (final c in comments)
        if (c.id != comment.id) c,
    ];
    notifyListeners();
  }

  // ---- settings and coin packs ----

  Future<void> loadSettings() async {
    settingsLoading = true;
    settingsError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.adminSettings(),
        _repository.adminCoinPacks(),
      ]);
      settings = results[0] as AdminSettings;
      coinPacks = results[1] as List<AdminCoinPack>;
    } on Object catch (e) {
      settingsError = errorMessage(e);
    }
    settingsLoading = false;
    notifyListeners();
  }

  Future<void> saveSettings(AdminSettings value) async {
    settings = await _repository.adminSaveSettings(value);
    notifyListeners();
  }

  Future<void> saveCoinPack({
    int? id,
    required String name,
    required int coins,
    required double priceUsd,
  }) async {
    await _repository.adminSaveCoinPack(
      id: id,
      name: name,
      coins: coins,
      priceUsd: priceUsd,
    );
    coinPacks = await _repository.adminCoinPacks();
    notifyListeners();
  }

  Future<void> deleteCoinPack(AdminCoinPack pack) async {
    await _repository.adminDeleteCoinPack(pack.id);
    coinPacks = [
      for (final p in coinPacks)
        if (p.id != pack.id) p,
    ];
    notifyListeners();
  }

  void reset() {
    sales = const AdminSales(totalUsd: 0);
    error = null;
    films = const [];
    filmsError = null;
    comments = const [];
    commentsError = null;
    settings = const AdminSettings();
    coinPacks = const [];
    settingsError = null;
    notifyListeners();
  }
}
