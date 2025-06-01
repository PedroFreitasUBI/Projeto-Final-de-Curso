import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  // Storage keys
  static const _rememberMeKey = 'remember_me';
  static const _usernameKey = 'saved_username';
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  
  static final _secureStorage = FlutterSecureStorage();
  static final _client = http.Client();

  /// Token Management
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  static Future<List<String>> getStationIds() async {
  final token = await getAccessToken();
  final response = await http.get(
    Uri.parse('http://10.0.2.2:5000/api/stations'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((station) => station.toString()).toList();
  }
  throw Exception('Failed to load stations: ${response.statusCode}');
}

static Future<Map<String, List<String>>> getMeasurementTypes() async {
  final token = await getAccessToken();
  final response = await http.get(
    Uri.parse('http://10.0.2.2:5000/api/measurement-types'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    final List<dynamic> types = jsonDecode(response.body);
    
    // Map to your unit system
    const unitMap = {
      'humidity': ['%', 'kg/m³', 'g/m³'],
      'max_wind': ['km/h', 'm/s', 'mph'],
      'wind_speed': ['km/h', 'm/s', 'mph'],
      'precipitation': ['mm', 'in'],
      'pressure': ['hPa', 'Pa', 'bar'],
      'temperature': ['°C', '°F', 'K'],
      'wind_direction': ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'],
      'soil_moisture': ['%', 'm³/m³']
    };
    
    // Only include types that exist in your database enum
    final validTypes = types.where((type) => unitMap.containsKey(type)).toList();
    return Map.fromIterable(
      validTypes,
      key: (type) => type.toString(),
      value: (type) => unitMap[type] ?? []
    );
  }
  throw Exception('Failed to load measurement types');
}

  /// Remember Me Functions
  static Future<bool> getRememberMeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  static Future<void> setRememberMe(bool remember, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, remember);
    if (remember) {
      await prefs.setString(_usernameKey, username);
    } else {
      await prefs.remove(_usernameKey);
    }
  }

  static Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Session Validation
  static Future<bool> validateSession() async {
    final token = await getAccessToken();
    if (token == null) return false;

    try {
      final response = await _client.get(
        Uri.parse('http://10.0.2.2:5000/check-session'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Logout Function
  static Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await Future.wait([
    _secureStorage.delete(key: _accessTokenKey),
    _secureStorage.delete(key: _refreshTokenKey),
    prefs.setBool(_rememberMeKey, false),
    prefs.setBool('explicit_logout', true), // Track that user explicitly logged out
    prefs.remove(_usernameKey),
  ]);
}

  /// Full Session Clear
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      clearTokens(),
      prefs.remove(_rememberMeKey),
      prefs.remove(_usernameKey),
    ]);
  }
}