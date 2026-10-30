import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class FeedController extends ChangeNotifier {
  FeedController(this.api);

  final ApiClient api;
}
