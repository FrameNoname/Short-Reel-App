import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';

class UploadController extends ChangeNotifier {
  UploadController(this.repository);

  final AppRepository repository;

  Future<void> submit({
    required int creatorId,
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    required List<int> episodePrices,
  }) async {
    await repository.upload(
      creatorId: creatorId,
      title: title,
      genre: genre,
      aiTool: aiTool,
      promptCredit: promptCredit,
      episodePrices: episodePrices,
    );
    notifyListeners();
  }

  void update(
    int filmId, {
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    Map<int, int> episodePrices = const {},
  }) {
    repository.setEpisodePrices(episodePrices);
    repository.updateFilm(
      filmId,
      title: title,
      genre: genre,
      aiTool: aiTool,
      promptCredit: promptCredit,
    );
    notifyListeners();
  }

  void remove(int filmId) {
    repository.deleteFilm(filmId);
    notifyListeners();
  }
}
