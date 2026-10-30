import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this.api);

  final ApiClient api;
}
