enum UserRole { guest, viewer, creator, admin }

class User {
  const User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.coinBalance,
  });

  final int id;
  final String username;
  final String? displayName;
  final UserRole role;
  final int coinBalance;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String,
        displayName: json['display_name'] as String?,
        role: UserRole.values.byName(json['role'] as String),
        coinBalance: json['coin_balance'] as int,
      );
}
