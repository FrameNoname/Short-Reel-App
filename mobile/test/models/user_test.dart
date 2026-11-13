// Person 1: the User model.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/models/user.dart';

void main() {
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
}
