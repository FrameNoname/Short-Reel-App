import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class WalletController extends ChangeNotifier {
  WalletController(this.api);

  final ApiClient api;
}
