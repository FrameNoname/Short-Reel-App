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
  Set<String> _preferred = const {};

  Future<void> load(int? userId) async {
    isLoading = true;
    notifyListeners();
    films = await _fetch(userId);
    isLoading = false;
    notifyListeners();
  }

  Future<List<Film>> _fetch(int? userId) async {
    final films = tab == FeedTab.following && userId != null
        ? await repository.followingFilms(userId)
        : await repository.films();
    if (_preferred.isEmpty) return films;
    // Liked genres first; the order inside each group is unchanged.
    return [
      ...films.where((f) => _preferred.contains(f.genreName)),
      ...films.where((f) => !_preferred.contains(f.genreName)),
    ];
  }

  /// Puts these genres at the top of the feed.
  void preferGenres(Set<String> genres) {
    _preferred = genres;
  }

  Future<void> selectTab(FeedTab value, int? userId) async {
    tab = value;
    await load(userId);
  }

  int currentEpisodeOf(int filmId) => _currentEpisode[filmId] ?? 1;

  void play(Episode episode, {int? userId}) {
    _currentEpisode[episode.filmId] = episode.episodeNo;
    if (userId != null) {
      repository.recordProgress(userId, episode.filmId, episode.episodeNo);
    }
    notifyListeners();
  }

  /// Picks a film up again at [episodeNo].
  void resume(int filmId, int episodeNo) {
    _currentEpisode[filmId] = episodeNo;
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
