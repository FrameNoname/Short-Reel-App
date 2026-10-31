import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/user.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AppRepository _repository;

  User? _user;
  bool _enteredAsGuest = false;

  User? get user => _user;

  UserRole get role => _user?.role ?? UserRole.guest;

  bool get isLoggedIn => _user != null;

  /// False until the person logs in or chooses to browse as a guest.
  bool get hasEntered => isLoggedIn || _enteredAsGuest;

  Future<void> login(String username, String password) async {
    _user = await _repository.login(username, password);
    notifyListeners();
  }

  Future<void> register(String username, String password, UserRole role) async {
    _user = await _repository.register(username, password, role);
    notifyListeners();
  }

  void continueAsGuest() {
    _enteredAsGuest = true;
    notifyListeners();
  }

  void logout() {
    _user = null;
    _enteredAsGuest = false;
    notifyListeners();
  }

  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }
}
