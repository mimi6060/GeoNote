class User {
  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final bool isAnonymous;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.isAnonymous = false,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isAnonymous: json['is_anonymous'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar_url': avatarUrl,
        'is_anonymous': isAnonymous,
        'created_at': createdAt.toIso8601String(),
      };
}
