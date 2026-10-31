import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../data/film_filter.dart';
import '../models/film.dart';

class FilmSearchController extends ChangeNotifier {
  FilmSearchController(this.repository);

  final AppRepository repository;

  FilmFilter filter = const FilmFilter();
  List<Film> results = const [];

  Future<void> apply(FilmFilter value) async {
    filter = value;
    results = await repository.films(value);
    notifyListeners();
  }

  Future<int> countFor(FilmFilter value) async =>
      (await repository.films(value)).length;
}
