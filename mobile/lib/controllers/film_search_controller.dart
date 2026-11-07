import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/film.dart';
import '../services/api_client.dart' show isStaleSession;
import '../services/errors.dart';

class FilmSearchController extends ChangeNotifier {
  FilmSearchController(this._repository);

  final AppRepository _repository;

  String query = '';
  List<Film> results = const [];

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

  /// How long typing has to pause before the search runs.
  static const typingPause = Duration(milliseconds: 300);

  Timer? _typing;

  /// Searches once typing pauses, so every key press does not hit the API.
  void type(String value) {
    _typing?.cancel();
    _typing = Timer(typingPause, () => apply(value));
  }

  Future<void> apply(String value) async {
    _typing?.cancel();
    final request = ++_request;
    query = value;
    error = null;
    try {
      final found = await _repository.films(value);
      if (request != _request) return;
      results = found;
    } on Object catch (e) {
      if (request != _request || isStaleSession(e)) return;
      results = const [];
      error = errorMessage(e);
    }
    notifyListeners();
  }

  Future<void> loadTrending() async {
    try {
      final films = [...await _repository.films()]
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

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }
}
