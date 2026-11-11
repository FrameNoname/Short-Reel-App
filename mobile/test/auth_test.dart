// Person 1: login, profile and the User model.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'package:shortreel/models/user.dart';

import 'support/fake_repository.dart';
import 'support/helpers.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

  group('User', () {
    test('reads the API shape and marks only admins as verified', () {
      final user = User.fromJson({
        'id': 1,
        'username': 'admin',
        'display_name': null,
        'role': 'admin',
        'coin_balance': 0,
      });
      expect(user.role, UserRole.admin);
      expect(user.isVerified, isTrue);
      expect(user.copyWith(coinBalance: 5).isVerified, isTrue);

      final viewer = User.fromJson({
        'id': 2,
        'username': 'v',
        'role': 'viewer',
        'coin_balance': 80,
        'bio': 'hi',
      });
      expect(viewer.isVerified, isFalse);
      expect(viewer.bio, 'hi');
    });

    test('copyWith keeps what it is not given', () {
      const user = User(
        id: 1,
        username: 'a',
        displayName: 'A',
        role: UserRole.viewer,
        coinBalance: 10,
        bio: 'b',
      );
      final updated = user.copyWith(coinBalance: 30);
      expect(updated.coinBalance, 30);
      expect(updated.displayName, 'A');
      expect(updated.bio, 'b');
    });
  });

  group('AuthController', () {
    test('login signs the person in and notifies', () async {
      final auth = AuthController(repo);
      var notified = 0;
      auth.addListener(() => notified++);

      await auth.login('viewer01', '6666');

      expect(auth.isLoggedIn, isTrue);
      expect(auth.role, UserRole.viewer);
      expect(auth.hasEntered, isTrue);
      expect(notified, greaterThan(0));
    });

    test('a failed login leaves nobody signed in', () async {
      repo.loginError = serverDown;
      final auth = AuthController(repo);
      await expectLater(auth.login('viewer01', 'x'), throwsA(serverDown));
      expect(auth.isLoggedIn, isFalse);
      expect(auth.role, UserRole.guest);
    });

    test('a guest has entered but is not logged in', () {
      final auth = AuthController(repo)..continueAsGuest();
      expect(auth.hasEntered, isTrue);
      expect(auth.isLoggedIn, isFalse);
    });

    test(
      'logout clears the user and runs the logout listeners even offline',
      () async {
        repo.logoutFails = true;
        final auth = AuthController(repo);
        var cleaned = false;
        auth.addLogoutListener(() => cleaned = true);
        await auth.login('viewer01', '6666');

        await auth.logout();

        expect(auth.user, isNull);
        expect(cleaned, isTrue);
        expect(auth.hasEntered, isFalse);
      },
    );

    test('a login that finishes after logout is dropped', () async {
      repo.loginGate = Completer<User>();
      final auth = AuthController(repo);
      final pending = auth.login('viewer01', '6666');
      await auth.logout();
      repo.loginGate!.complete(repo.viewer);
      await pending;
      expect(auth.isLoggedIn, isFalse);
    });

    test('restoreSession signs in from the stored token', () async {
      repo.stored = repo.viewer;
      final auth = AuthController(repo);
      await auth.restoreSession();
      expect(auth.user?.id, repo.viewer.id);
      expect(auth.isRestoring, isFalse);
    });

    test('updateUser ignores a copy of someone else', () async {
      final auth = AuthController(repo);
      await auth.login('viewer01', '6666');
      auth.updateUser(
        const User(
          id: 999,
          username: 'other',
          displayName: null,
          role: UserRole.viewer,
          coinBalance: 1,
        ),
      );
      expect(auth.user!.id, repo.viewer.id);
      auth.updateUser(repo.viewer.copyWith(coinBalance: 5));
      expect(auth.user!.coinBalance, 5);
    });
  });

  group('AuthController, more', () {
    test('register signs the new viewer in', () async {
      final auth = AuthController(repo);
      await auth.register('newbie', 'pw');
      expect(auth.user?.displayName, 'newbie');
      expect(repo.calls, ['register newbie']);
    });

    test('a broken stored token leaves the person signed out', () async {
      final auth = _ThrowingRestore();
      final controller = AuthController(auth);
      await controller.restoreSession();
      expect(controller.isLoggedIn, isFalse);
      expect(controller.isRestoring, isFalse);
    });

    test('a login during restore wins over the stored token', () async {
      final gate = Completer<User?>();
      final slow = _SlowRestore(gate);
      final auth = AuthController(slow);
      final restoring = auth.restoreSession();
      expect(auth.isRestoring, isTrue);
      await auth.login('viewer01', 'pw');
      gate.complete(slow.viewer.copyWith(displayName: 'Old'));
      await restoring;
      expect(auth.user?.displayName, 'Viewer');
      expect(auth.isRestoring, isFalse);
    });

    test('logout signs out even when the server cannot be reached', () async {
      repo.logoutFails = true;
      final auth = AuthController(repo);
      var dropped = 0;
      auth.addLogoutListener(() => dropped++);
      await auth.login('viewer01', 'pw');
      auth.continueAsGuest();

      await auth.logout();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.hasEntered, isFalse);
      expect(dropped, 1);
    });

    test('an expired session clears the token and signs out', () async {
      final auth = AuthController(repo);
      var dropped = 0;
      auth.addLogoutListener(() => dropped++);
      await auth.login('viewer01', 'pw');

      auth.sessionExpired();

      expect(repo.calls, contains('clearSession'));
      expect(auth.user, isNull);
      expect(dropped, 1);
    });

    test('updateProfile changes the signed-in person only', () async {
      final auth = AuthController(repo);
      await auth.updateProfile(displayName: 'Nobody', bio: '');
      expect(repo.calls, isEmpty);

      await auth.login('viewer01', 'pw');
      await auth.updateProfile(displayName: 'Mira', bio: 'Hi');
      expect(auth.user?.displayName, 'Mira');
      expect(auth.user?.bio, 'Hi');
    });
  });
}

class _ThrowingRestore extends FakeRepository {
  @override
  Future<User?> restoreSession() async => throw serverDown;
}

class _SlowRestore extends FakeRepository {
  _SlowRestore(this.gate);

  final Completer<User?> gate;

  @override
  Future<User?> restoreSession() => gate.future;
}
