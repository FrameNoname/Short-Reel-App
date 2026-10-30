import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class UploadController extends ChangeNotifier {
  UploadController(this.api);

  final ApiClient api;
}
