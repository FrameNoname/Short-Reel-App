import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/film.dart';

class AdminController extends ChangeNotifier {
  AdminController(this.repository);

  final AppRepository repository;

  List<Film> get queue => repository.reviewQueue();

  List<Film> get liveFilms => repository.liveFilms();

  List<FilmReport> get reports => repository.openReports();

  AdminSales get sales => repository.adminSales();

  int get adminSharePercent => repository.adminSharePercent;

  void setAdminShare(int percent) {
    repository.setAdminSharePercent(percent);
    notifyListeners();
  }

  void review(int filmId, String status, {String? note}) {
    repository.review(filmId, status, note: note);
    notifyListeners();
  }

  void resolveReport(int reportId) {
    repository.resolveReport(reportId);
    notifyListeners();
  }
}
