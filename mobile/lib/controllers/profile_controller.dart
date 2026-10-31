import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this.repository);

  final AppRepository repository;
}
