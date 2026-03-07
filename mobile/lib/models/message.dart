class Message {
  final String id;
  final String userId;
  final String username;
  final String content;
  final double latitude;
  final double longitude;
  final String visibility;
  final List<String> hashtags;
  final int likesCount;
  final int commentsCount;
  final double? distanceMeters;
  final DateTime createdAt;
  final String messageType;
  final DateTime? expiresAt;
  final int mysteryRadius;
  final DateTime? scheduledAt;
  final int unlocksCount;

  const Message({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.latitude,
    required this.longitude,
    this.visibility = 'public',
    this.hashtags = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.distanceMeters,
    required this.createdAt,
    this.messageType = 'standard',
    this.expiresAt,
    this.mysteryRadius = 50,
    this.scheduledAt,
    this.unlocksCount = 0,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        username: json['username'] as String,
        content: json['content'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        visibility: json['visibility'] as String? ?? 'public',
        hashtags: (json['hashtags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        likesCount: json['likes_count'] as int? ?? 0,
        commentsCount: json['comments_count'] as int? ?? 0,
        distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        messageType: json['message_type'] as String? ?? 'standard',
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
        mysteryRadius: json['mystery_radius'] as int? ?? 50,
        scheduledAt: json['scheduled_at'] != null
            ? DateTime.parse(json['scheduled_at'] as String)
            : null,
        unlocksCount: json['unlocks_count'] as int? ?? 0,
      );

  bool get isMystery => messageType == 'mystery';
  bool get isCapsule => messageType == 'capsule';
  bool get isEphemeral => expiresAt != null;
  bool get isLocked => isMystery && content == '???';

  String get timeRemaining {
    if (expiresAt == null) return '';
    final diff = expiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Expire';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}min';
  }

  String get distanceFormatted {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()}m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)}km';
  }
}
