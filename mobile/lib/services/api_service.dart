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

  // ---- Messages ----

  Future<List<Message>> getNearbyMessages({
    required double latitude,
    required double longitude,
    int radius = 10000,
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
    return list
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Message> createMessage({
    required String content,
    required double latitude,
    required double longitude,
    String visibility = 'public',
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        'latitude': latitude,
        'longitude': longitude,
        'visibility': visibility,
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

  // ---- Interactions ----

  Future<bool> toggleLike(String messageId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/like'),
      headers: _headers,
    );
    _checkError(response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data']['liked'] as bool;
  }

  void _checkError(http.Response response) {
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(body['error']?['message'] ?? 'Erreur ${response.statusCode}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
