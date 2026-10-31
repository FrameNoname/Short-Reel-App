import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/user.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AppRepository _repository;

  User? _user;
  bool _enteredAsGuest = false;
  bool _restoring = false;
  final List<VoidCallback> _onLogout = [];

  User? get user => _user;

  UserRole get role => _user?.role ?? UserRole.guest;

  bool get isLoggedIn => _user != null;

  /// True while the stored token is being checked on app start.
  bool get isRestoring => _restoring;

  /// False until the person logs in or chooses to browse as a guest.
  bool get hasEntered => isLoggedIn || _enteredAsGuest;

  /// Runs [callback] when someone logs out, so other controllers can drop
  /// what belonged to them.
  void addLogoutListener(VoidCallback callback) => _onLogout.add(callback);

  /// Signs back in from the token kept on the device.
  Future<void> restoreSession() async {
    _restoring = true;
    notifyListeners();
    try {
      _user = await _repository.restoreSession();
    } on Object {
      _user = null;
    }
    _restoring = false;
    notifyListeners();
  }

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

  /// Clears the token and everything held for the person.
  Future<void> logout() async {
    try {
      await _repository.logout();
    } on Object {
      // The token is dropped locally either way.
    }
    _expire();
  }

  /// The server no longer accepts the token: behave as if logged out.
  void sessionExpired() {
    _repository.clearSession();
    _expire();
  }

  void _expire() {
    _user = null;
    _enteredAsGuest = false;
    for (final callback in _onLogout) {
      callback();
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
  }) async {
    final user = _user;
    if (user == null) return;
    _user = await _repository.updateProfile(
      user.id,
      displayName: displayName,
      bio: bio,
    );
    notifyListeners();
  }

  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }
}
