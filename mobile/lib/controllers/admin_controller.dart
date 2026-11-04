import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/film.dart';
import '../services/errors.dart';

class AdminController extends ChangeNotifier {
  AdminController(this.repository);

  final AppRepository repository;

  List<Film> queue = const [];
  List<Film> liveFilms = const [];
  AdminSales sales = const AdminSales(totalUsd: 0, adminCoins: 0);
  int adminSharePercent = 30;
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        repository.reviewQueue(),
        repository.liveFilms(),
        repository.adminSales(),
        repository.adminSharePercent(),
      ]);
      queue = results[0] as List<Film>;
      liveFilms = results[1] as List<Film>;
      sales = results[2] as AdminSales;
      adminSharePercent = results[3] as int;
    } on Object catch (e) {
      error = errorMessage(e);
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> setAdminShare(int percent) async {
    await repository.setAdminSharePercent(percent);
    adminSharePercent = percent;
    notifyListeners();
  }

  Future<void> review(int filmId, String status, {String? note}) async {
    await repository.review(filmId, status, note: note);
    await load();
  }

  void reset() {
    queue = const [];
    liveFilms = const [];
    sales = const AdminSales(totalUsd: 0, adminCoins: 0);
    error = null;
    notifyListeners();
  }
}
