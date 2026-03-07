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
      );

  String get distanceFormatted {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()}m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)}km';
  }
}
