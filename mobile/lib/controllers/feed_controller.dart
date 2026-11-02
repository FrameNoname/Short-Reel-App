import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/episode.dart';
import '../models/film.dart';
import '../services/api_client.dart' show isStaleSession;
import '../services/errors.dart';

enum FeedTab { following, forYou }

class FeedController extends ChangeNotifier {
  FeedController(this.repository);

  final AppRepository repository;

  List<Film> films = const [];
  FeedTab tab = FeedTab.forYou;
  bool isLoading = true;

  final Map<int, int> _currentEpisode = {};
  final Map<int, List<int>> _episodeNumbers = {};

  // Counts feed loads; an answer from an older load is dropped, so a slow reply
  // for one tab can never replace the films of the tab chosen after it.
  int _loadId = 0;
  Set<String> _preferred = const {};

  /// Why the last load failed, or null.
  String? error;

  Future<void> load(int? userId) async {
    final id = ++_loadId;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final loaded = await _fetch(userId);
      if (id != _loadId) return;
      films = loaded;
    } on Object catch (e) {
      if (id != _loadId || isStaleSession(e)) return;
      films = const [];
      error = errorMessage(e);
    }
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

  /// The episode numbers a film really has (they need not run 1, 2, 3...).
  void learnEpisodes(int filmId, List<int> numbers) {
    _episodeNumbers[filmId] = [...numbers]..sort();
  }

  /// The episode after [current] in the film's real list, or null at the end.
  /// Until the list is known, falls back to counting from the episode count.
  int? episodeAfter(int filmId, int current, {required int fallbackCount}) {
    final known = _episodeNumbers[filmId];
    if (known == null) return current < fallbackCount ? current + 1 : null;
    for (final number in known) {
      if (number > current) return number;
    }
    return null;
  }

  void play(Episode episode) {
    _currentEpisode[episode.filmId] = episode.episodeNo;
    notifyListeners();
  }

  /// Picks a film up again at [episodeNo].
  void resume(int filmId, int episodeNo) {
    _currentEpisode[filmId] = episodeNo;
    notifyListeners();
  }

  /// Forgets everything that belonged to the last person.
  void reset() {
    films = const [];
    error = null;
    tab = FeedTab.forYou;
    _currentEpisode.clear();
    _episodeNumbers.clear();
    _loadId++;
    notifyListeners();
  }

  Future<void> toggleLike(int userId, int filmId) async {
    await repository.toggleLike(userId, filmId);
    films = await _fetch(userId);
    notifyListeners();
  }

  Future<void> addComment(
    int userId,
    int filmId,
    String body, {
    int? parentId,
  }) async {
    await repository.addComment(userId, filmId, body, parentId: parentId);
    films = await _fetch(userId);
    notifyListeners();
  }

  void toggleCommentLike(int userId, int commentId) {
    repository.toggleCommentLike(userId, commentId);
    notifyListeners();
  }

  Future<void> removeComment(int userId, int commentId) async {
    await repository.removeComment(commentId);
    films = await _fetch(userId);
    notifyListeners();
  }

  Future<void> reportFilm(int userId, int filmId, String reason) =>
      repository.reportFilm(userId, filmId, reason);

  Future<void> toggleSave(int userId, int filmId) async {
    await repository.toggleSave(userId, filmId);
    notifyListeners();
  }

  Future<void> toggleFollow(int userId, int creatorId) async {
    await repository.toggleFollow(userId, creatorId);
    notifyListeners();
  }
}
