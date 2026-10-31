import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../data/film_filter.dart';
import '../models/film.dart';
import '../models/user.dart';
import '../services/errors.dart';

class FilmSearchController extends ChangeNotifier {
  FilmSearchController(this.repository);

  final AppRepository repository;

  FilmFilter filter = const FilmFilter();
  List<Film> results = const [];
  List<User> creators = const [];

  /// Words the person searched for, the latest first.
  List<String> recent = const [];

  /// The most watched films right now.
  List<Film> trending = const [];

  /// Genres from the catalog, offered next to the built-in ones.
  List<String> get catalogGenres => repository.catalogGenres();

  static const _maxRecent = 8;

  /// Why the last search failed, or null.
  String? error;

  Future<void> apply(FilmFilter value) async {
    filter = value;
    error = null;
    try {
      results = await repository.films(value);
      creators = repository.searchCreators(value.query);
    } on Object catch (e) {
      results = const [];
      error = errorMessage(e);
    }
    notifyListeners();
  }

  Future<void> loadTrending() async {
    try {
      final films = [...await repository.films()]
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
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

  Future<int> countFor(FilmFilter value) async =>
      (await repository.films(value)).length;
}
