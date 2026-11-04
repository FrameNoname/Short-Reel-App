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

  /// Bumped on every login, logout and expiry. An answer that was asked for
  /// under an older number is ignored, so a slow request of the previous
  /// person can never change, or bring back, the current one.
  int _epoch = 0;

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
    final epoch = _epoch;
    _restoring = true;
    notifyListeners();
    User? restored;
    try {
      restored = await _repository.restoreSession();
    } on Object {
      restored = null;
    }
    if (epoch != _epoch) {
      // Someone logged in or out while the stored token was being checked.
      _restoring = false;
      notifyListeners();
      return;
    }
    _user = restored;
    _restoring = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final epoch = ++_epoch;
    final user = await _repository.login(username, password);
    if (epoch != _epoch) return;
    _user = user;
    notifyListeners();
  }

  /// Signs up a new viewer account.
  Future<void> register(String username, String password) async {
    final epoch = ++_epoch;
    final user = await _repository.register(username, password);
    if (epoch != _epoch) return;
    _user = user;
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
    _epoch++;
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
    final epoch = _epoch;
    final updated = await _repository.updateProfile(
      user.id,
      displayName: displayName,
      bio: bio,
    );
    if (epoch != _epoch || _user?.id != user.id) return;
    _user = updated;
    notifyListeners();
  }

  /// Applies a fresh copy of the signed-in person (a new balance, say). Dropped
  /// when nobody is signed in or it describes someone else.
  void updateUser(User user) {
    if (_user?.id != user.id) return;
    _user = user;
    notifyListeners();
  }
}
