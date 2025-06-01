import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SessionService {
  static final _storage = FlutterSecureStorage();
  static final _client = http.Client();
  
  static Future<bool> validateSession() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return false;
      
      final response = await _client.get(
        Uri.parse('http://10.0.2.2:5000/check-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'active';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> shouldAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: 'auth_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_me');
  }

  static Future<void> saveSession(String token, bool rememberMe) async {
    await _storage.write(key: 'auth_token', value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', rememberMe);
  }
}