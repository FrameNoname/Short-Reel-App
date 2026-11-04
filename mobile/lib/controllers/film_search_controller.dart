import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/film.dart';
import '../models/user.dart';
import '../services/api_client.dart' show isStaleSession;
import '../services/errors.dart';

class FilmSearchController extends ChangeNotifier {
  FilmSearchController(this.repository);

  final AppRepository repository;

  String query = '';
  List<Film> results = const [];
  List<User> creators = const [];

  /// Words the person searched for, the latest first.
  List<String> recent = const [];

  /// The most watched films right now.
  List<Film> trending = const [];

  static const _maxRecent = 8;

  /// Why the last search failed, or null.
  String? error;

  // Counts searches; only the newest one may change what is on screen, so a
  // slow answer for an old word can never replace the answer to the current one.
  int _request = 0;

  Future<void> apply(String value) async {
    final request = ++_request;
    query = value;
    error = null;
    try {
      final found = await repository.films(value);
      if (request != _request) return;
      results = found;
      creators = repository.searchCreators(value);
    } on Object catch (e) {
      if (request != _request || isStaleSession(e)) return;
      results = const [];
      error = errorMessage(e);
    }
    notifyListeners();
  }

  Future<void> loadTrending() async {
    try {
      final films = [...await repository.films()]
        ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
      trending = films.take(5).toList();
    } on Object {
      // Trending is a nicety; search itself reports its own errors.
    }
    notifyListeners();
  }

  /// Keeps [term] at the top of the recent searches.
  void remember(String term) {
    final text = term.trim();
    if (text.isEmpty) return;
    recent = [
      text,
      ...recent.where((t) => t.toLowerCase() != text.toLowerCase()),
    ].take(_maxRecent).toList();
    notifyListeners();
  }

  void forget(String term) {
    recent = recent.where((t) => t != term).toList();
    notifyListeners();
  }

  void clearRecent() {
    recent = const [];
    notifyListeners();
  }
}
