class ReactionSummary {
  final String emoji;
  final int count;
  final bool reacted;

  const ReactionSummary({
    required this.emoji,
    required this.count,
    this.reacted = false,
  });

  factory ReactionSummary.fromJson(Map<String, dynamic> json) =>
      ReactionSummary(
        emoji: json['emoji'] as String,
        count: json['count'] as int? ?? 0,
        reacted: json['reacted'] as bool? ?? false,
      );
}

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
  final List<ReactionSummary> reactions;

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
    this.reactions = const [],
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
        reactions: (json['reactions'] as List<dynamic>?)
                ?.map((e) => ReactionSummary.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
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

  bool get isCapsuleRevealed => isCapsule && scheduledAt != null && DateTime.now().isAfter(scheduledAt!);
  bool get isCapsulePending => isCapsule && scheduledAt != null && DateTime.now().isBefore(scheduledAt!);

  String get capsuleCountdown {
    if (scheduledAt == null) return '';
    final diff = scheduledAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Revele !';
    if (diff.inDays > 0) return '${diff.inDays}j ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}min';
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
