import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class AdminController extends ChangeNotifier {
  AdminController(this.api);

  final ApiClient api;
}
