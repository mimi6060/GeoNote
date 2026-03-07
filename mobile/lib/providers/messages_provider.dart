import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/message.dart';
import '../services/api_service.dart';

class MessagesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<Message> _messages = [];
  bool _loading = false;
  String? _error;

  List<Message> get messages => _messages;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadNearby(LatLng center, {int radius = 10000}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await _api.getNearbyMessages(
        latitude: center.latitude,
        longitude: center.longitude,
        radius: radius,
      );
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> create({
    required String content,
    required double latitude,
    required double longitude,
    String visibility = 'public',
  }) async {
    await _api.createMessage(
      content: content,
      latitude: latitude,
      longitude: longitude,
      visibility: visibility,
    );
  }

  Future<void> toggleLike(String messageId) async {
    await _api.toggleLike(messageId);
  }

  Future<Map<String, dynamic>> toggleLikeAndReturn(String messageId) async {
    return await _api.toggleLikeRaw(messageId);
  }
}
