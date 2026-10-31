import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../services/video_picker.dart';

class UploadController extends ChangeNotifier {
  UploadController(this.repository, {this.pickVideos = pickVideosFromDevice});

  final AppRepository repository;

  /// Opens the device's video picker; tests pass a fake.
  final VideoPicker pickVideos;

  bool isBusy = false;

  /// Creates the film and uploads every episode. Returns only after the server
  /// has answered for each of them; a failure is thrown to the caller.
  Future<void> submit({
    required int creatorId,
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    required List<EpisodeDraft> episodes,
  }) async {
    isBusy = true;
    notifyListeners();
    try {
      await repository.upload(
        creatorId: creatorId,
        title: title,
        genre: genre,
        aiTool: aiTool,
        promptCredit: promptCredit,
        episodes: episodes,
      );
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> update(
    int filmId, {
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    Map<int, int> episodePrices = const {},
  }) async {
    await repository.setEpisodePrices(episodePrices);
    await repository.updateFilm(
      filmId,
      title: title,
      genre: genre,
      aiTool: aiTool,
      promptCredit: promptCredit,
    );
    notifyListeners();
  }

  Future<void> remove(int filmId) async {
    await repository.deleteFilm(filmId);
    notifyListeners();
  }
}
