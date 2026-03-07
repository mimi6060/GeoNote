import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  User? _user;
  String? _token;
  bool _loading = false;

  User? get user => _user;
  bool get isLoggedIn => _token != null;
  bool get loading => _loading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      _api.setToken(_token);
      try {
        _user = await _api.getMe();
      } catch (_) {
        // Token expired or invalid — clear session
        _token = null;
        _api.setToken(null);
        await prefs.remove('token');
      }
    }
    notifyListeners();
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final result = await _api.register(
        username: username,
        email: email,
        password: password,
      );
      await _saveAuth(result.token, result.user);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final result = await _api.login(email: email, password: password);
      await _saveAuth(result.token, result.user);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _token = null;
    _user = null;
    _api.setToken(null);
    notifyListeners();
  }

  Future<void> _saveAuth(String token, User user) async {
    _token = token;
    _user = user;
    _api.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
}
