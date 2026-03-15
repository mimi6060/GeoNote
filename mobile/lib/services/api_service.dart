import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/message.dart';
import '../models/user.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  String? get token => _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ---- Auth ----

  Future<({String token, User user})> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    return _parseAuthResponse(response);
  }

  Future<({String token, User user})> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseAuthResponse(response);
  }

  ({String token, User user}) _parseAuthResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(body['error']?['message'] ?? 'Erreur');
    }
    final data = body['data'] as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<User> getMe() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: _headers,
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ---- Messages ----

  Future<List<Message>> getNearbyMessages({
    required double latitude,
    required double longitude,
    int radius = 1000,
    int limit = 50,
    String sort = 'distance',
    String? hashtag,
  }) async {
    final params = {
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      'radius': radius.toString(),
      'limit': limit.toString(),
      'sort': sort,
      if (hashtag != null && hashtag.isNotEmpty) 'hashtag': hashtag,
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/messages/nearby')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data']['messages'] as List<dynamic>;
    return list.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Message> createMessage({
    required String content,
    required double latitude,
    required double longitude,
    String visibility = 'public',
    String messageType = 'standard',
    int mysteryRadius = 50,
    String? scheduledAt,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        'latitude': latitude,
        'longitude': longitude,
        'visibility': visibility,
        'message_type': messageType,
        if (messageType == 'mystery') 'mystery_radius': mysteryRadius,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
      }),
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Message.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> deleteMessage(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/messages/$id'),
      headers: _headers,
    );
    _checkError(response);
  }

  Future<List<Message>> getUserMessages(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/$userId/messages'),
      headers: _headers,
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data']['messages'] as List<dynamic>;
    return list.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---- Mystery unlock ----

  Future<Map<String, dynamic>> unlockMystery(String messageId, double lat, double lng) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/unlock'),
      headers: _headers,
      body: jsonEncode({'latitude': lat, 'longitude': lng}),
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  // ---- Heatmap ----

  Future<List<Map<String, dynamic>>> getHeatmap(double lat, double lng, {int radius = 1000}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/heatmap').replace(queryParameters: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
    });
    final response = await http.get(uri, headers: _headers);
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data']['points'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ---- Leaderboard ----

  Future<List<Map<String, dynamic>>> getLeaderboard(double lat, double lng, {int radius = 5000}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/leaderboard').replace(queryParameters: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
    });
    final response = await http.get(uri, headers: _headers);
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data']['leaderboard'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ---- Gamification profile ----

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/me/profile'),
      headers: _headers,
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/$userId/profile'),
      headers: _headers,
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  // ---- Events ----

  Future<List<Map<String, dynamic>>> getEvents(double lat, double lng, {int radius = 5000}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/events').replace(queryParameters: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
    });
    final response = await http.get(uri, headers: _headers);
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data']['events'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ---- Search ----

  Future<Map<String, dynamic>> search(String query, {String type = 'hashtag', int limit = 20, int offset = 0}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/search').replace(queryParameters: {
      'q': query,
      'type': type,
      'limit': limit.toString(),
      'offset': offset.toString(),
    });
    final response = await http.get(uri, headers: _headers);
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPopularHashtags({int limit = 10}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/search/hashtags/popular').replace(queryParameters: {
      'limit': limit.toString(),
    });
    final response = await http.get(uri, headers: _headers);
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data']['hashtags'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ---- Interactions ----

  Future<Map<String, dynamic>> toggleReaction(String messageId, String emoji) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/react'),
      headers: _headers,
      body: jsonEncode({'emoji': emoji}),
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  Future<bool> toggleLike(String messageId) async {
    final data = await toggleLikeRaw(messageId);
    return data['liked'] as bool;
  }

  Future<Map<String, dynamic>> toggleLikeRaw(String messageId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/like'),
      headers: _headers,
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getComments(String messageId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/comments'),
      headers: _headers,
    );
    _checkError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data']['comments'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> addComment(String messageId, String content) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/comments'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    _checkError(response);
  }

  Future<void> deleteComment(String commentId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/comments/$commentId'),
      headers: _headers,
    );
    _checkError(response);
  }

  Future<void> reportMessage(String messageId, String reason, {String description = ''}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/report'),
      headers: _headers,
      body: jsonEncode({
        'reason': reason,
        'description': description,
      }),
    );
    _checkError(response);
  }

  void _checkError(http.Response response) {
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        body['error']?['message'] ?? 'Erreur ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, {this.statusCode = 0});

  @override
  String toString() => message;
}
