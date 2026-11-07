import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/film.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._repository);

  final AppRepository _repository;

  /// Loads the saved and unlocked lists the profile shows.
  Future<void> load(int userId) async {
    try {
      await _repository.refreshLibrary(userId);
    } on Object {
      // The lists simply stay as they were; the profile still opens.
    }
    notifyListeners();
  }

  /// Films this person saved, as of the last [load].
  List<Film> watchlistOf(int userId) => _repository.watchlistOf(userId);

  /// Films this person unlocked an episode of, as of the last [load].
  List<Film> unlockedFilmsOf(int userId) => _repository.unlockedFilmsOf(userId);
}
