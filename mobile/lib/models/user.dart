enum UserRole { guest, viewer, admin }

class User {
  const User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.coinBalance,
    this.bio,
  });

  final int id;
  final String username;
  final String? displayName;
  final UserRole role;
  final int coinBalance;

  /// A short line about the channel, shown under the name.
  final String? bio;

  /// Only admin channels carry the verified check.
  bool get isVerified => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    role: UserRole.values.byName(json['role'] as String),
    coinBalance: json['coin_balance'] as int,
    bio: json['bio'] as String?,
  );

  User copyWith({int? coinBalance, String? displayName, String? bio}) => User(
    id: id,
    username: username,
    displayName: displayName ?? this.displayName,
    role: role,
    coinBalance: coinBalance ?? this.coinBalance,
    bio: bio ?? this.bio,
  );
}
