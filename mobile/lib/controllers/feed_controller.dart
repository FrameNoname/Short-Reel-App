import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/episode.dart';
import '../models/film.dart';

enum FeedTab { following, forYou }

class FeedController extends ChangeNotifier {
  FeedController(this.repository);

  final AppRepository repository;

  List<Film> films = const [];
  FeedTab tab = FeedTab.forYou;
  bool isLoading = true;

  final Map<int, int> _currentEpisode = {};

  Future<void> load(int? userId) async {
    isLoading = true;
    notifyListeners();
    films = await _fetch(userId);
    isLoading = false;
    notifyListeners();
  }

  Future<List<Film>> _fetch(int? userId) {
    return tab == FeedTab.following && userId != null
        ? repository.followingFilms(userId)
        : repository.films();
  }

  Future<void> selectTab(FeedTab value, int? userId) async {
    tab = value;
    await load(userId);
  }

  int currentEpisodeOf(int filmId) => _currentEpisode[filmId] ?? 1;

  void play(Episode episode) {
    _currentEpisode[episode.filmId] = episode.episodeNo;
    notifyListeners();
  }

  Future<void> toggleLike(int userId, int filmId) async {
    repository.toggleLike(userId, filmId);
    films = await _fetch(userId);
    notifyListeners();
  }

  Future<void> addComment(
    int userId,
    int filmId,
    String body, {
    int? parentId,
  }) async {
    repository.addComment(userId, filmId, body, parentId: parentId);
    films = await _fetch(userId);
    notifyListeners();
  }

  void toggleCommentLike(int userId, int commentId) {
    repository.toggleCommentLike(userId, commentId);
    notifyListeners();
  }

  Future<void> removeComment(int userId, int commentId) async {
    repository.removeComment(commentId);
    films = await _fetch(userId);
    notifyListeners();
  }

  void reportFilm(int userId, int filmId, String reason) {
    repository.reportFilm(userId, filmId, reason);
  }

  void toggleSave(int userId, int filmId) {
    repository.toggleSave(userId, filmId);
    notifyListeners();
  }

  void toggleFollow(int userId, int creatorId) {
    repository.toggleFollow(userId, creatorId);
    notifyListeners();
  }
}
