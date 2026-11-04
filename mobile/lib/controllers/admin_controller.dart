import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/film.dart';
import '../services/errors.dart';

class AdminController extends ChangeNotifier {
  AdminController(this.repository);

  final AppRepository repository;

  List<Film> liveFilms = const [];
  AdminSales sales = const AdminSales(totalUsd: 0);
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        repository.liveFilms(),
        repository.adminSales(),
      ]);
      liveFilms = results[0] as List<Film>;
      sales = results[1] as AdminSales;
    } on Object catch (e) {
      error = errorMessage(e);
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> takeDown(int filmId) async {
    await repository.takeDown(filmId);
    await load();
  }

  void reset() {
    liveFilms = const [];
    sales = const AdminSales(totalUsd: 0);
    error = null;
    notifyListeners();
  }
}
