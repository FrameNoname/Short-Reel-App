import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/catalog.dart';
import '../models/episode.dart';
import '../models/film.dart';
import '../services/api_client.dart' show isStaleSession;
import '../services/errors.dart';

class FeedController extends ChangeNotifier {
  FeedController(this._repository);

  final AppRepository _repository;

  List<Film> films = const [];
  bool isLoading = true;

  final Map<int, int> _currentEpisode = {};
  final Map<int, List<int>> _episodeNumbers = {};

  // Counts feed loads; an answer from an older load is dropped, so a slow reply
  // can never replace the films of a load started after it.
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
    final films = await _repository.films();
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
    _currentEpisode.clear();
    _episodeNumbers.clear();
    _loadId++;
    notifyListeners();
  }

  Future<void> toggleLike(int userId, int filmId) async {
    await _repository.toggleLike(userId, filmId);
    _showLatest();
  }

  Future<void> addComment(int userId, int filmId, String body) async {
    await _repository.addComment(userId, filmId, body);
    _showLatest();
  }

  Future<void> removeComment(int userId, int commentId) async {
    await _repository.removeComment(commentId);
    _showLatest();
  }

  /// The repository already updated its copy of the film (like and comment
  /// counts), so the feed swaps that in instead of reloading every film.
  void _showLatest() {
    films = [for (final film in films) _repository.filmById(film.id) ?? film];
    notifyListeners();
  }

  // ---- reads the views need; they never touch the repository -------------

  /// Whether this build streams real video rather than placeholders.
  bool get playsVideo => _repository.playsVideo;

  bool isLiked(int userId, int filmId) => _repository.isLiked(userId, filmId);

  bool isSaved(int userId, int filmId) => _repository.isSaved(userId, filmId);

  Future<List<Episode>> episodes(int filmId) => _repository.episodes(filmId);

  EpisodeAccess accessOf(int? userId, Episode episode) =>
      _repository.accessOf(userId, episode);

  bool catalogEpisodeLocked(Film film, int episodeNo) =>
      _repository.catalogEpisodeLocked(film, episodeNo);

  /// Where to stream an episode from, once access is confirmed.
  Future<Playback> playback(int episodeId) => _repository.playback(episodeId);

  /// The feed film for a catalog series, made once and then reused.
  Film catalogFilm(CatalogDrama drama) => _repository.catalogFilm(drama);

  Future<void> loadComments(int filmId) => _repository.loadComments(filmId);

  List<FilmComment> commentsOf(int filmId) => _repository.commentsOf(filmId);

  Future<void> toggleSave(int userId, int filmId) async {
    await _repository.toggleSave(userId, filmId);
    notifyListeners();
  }
}
