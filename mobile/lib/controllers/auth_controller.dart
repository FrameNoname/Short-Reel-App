import 'package:flutter/foundation.dart';

import '../models/user.dart';

class AuthController extends ChangeNotifier {
  AuthController({this.role = UserRole.guest});

  final UserRole role;

  bool get isLoggedIn => role != UserRole.guest;
}
