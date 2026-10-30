import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class FilmSearchController extends ChangeNotifier {
  FilmSearchController(this.api);

  final ApiClient api;
}
