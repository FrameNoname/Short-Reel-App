import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this.repository);

  final AppRepository repository;

  /// Loads the saved and unlocked lists the profile shows.
  Future<void> load(int userId) async {
    try {
      await repository.refreshLibrary(userId);
    } on Object {
      // The lists simply stay as they were; the profile still opens.
    }
    notifyListeners();
  }
}
