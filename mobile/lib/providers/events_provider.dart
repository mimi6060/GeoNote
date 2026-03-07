import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';

class GeoEvent {
  final double lat;
  final double lng;
  final int messageCount;
  final int userCount;
  final DateTime firstMessageAt;
  final DateTime lastMessageAt;
  final List<String> topHashtags;

  const GeoEvent({
    required this.lat,
    required this.lng,
    required this.messageCount,
    required this.userCount,
    required this.firstMessageAt,
    required this.lastMessageAt,
    this.topHashtags = const [],
  });

  factory GeoEvent.fromJson(Map<String, dynamic> json) => GeoEvent(
        lat: (json['grid_lat'] as num).toDouble(),
        lng: (json['grid_lng'] as num).toDouble(),
        messageCount: (json['message_count'] as num).toInt(),
        userCount: (json['user_count'] as num).toInt(),
        firstMessageAt: DateTime.parse(json['first_message_at'] as String),
        lastMessageAt: DateTime.parse(json['last_message_at'] as String),
        topHashtags: (json['top_hashtags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  String get label {
    if (topHashtags.isNotEmpty) return '#${topHashtags.first}';
    return '$messageCount posts';
  }

  String get subtitle {
    final ago = DateTime.now().difference(lastMessageAt);
    if (ago.inMinutes < 5) return 'En cours';
    if (ago.inMinutes < 60) return 'il y a ${ago.inMinutes}min';
    return 'il y a ${ago.inHours}h';
  }
}

class EventsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<GeoEvent> _events = [];

  List<GeoEvent> get events => _events;

  Future<void> loadNearby(LatLng center, {int radius = 5000}) async {
    try {
      final raw = await _api.getEvents(center.latitude, center.longitude, radius: radius);
      _events = raw.map((e) => GeoEvent.fromJson(e)).toList();
    } catch (_) {
      _events = [];
    }
    notifyListeners();
  }
}
