import 'package:http/http.dart' as http;

class Session {
  static final Session _instance = Session._internal();
  factory Session() => _instance;
  
  final http.Client _client = http.Client();
  Map<String, String> cookies = {};

  Session._internal();

  Future<http.Response> get(String url, {String? token}) async {
    final headers = _buildHeaders();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _client.get(
      Uri.parse(url),
      headers: headers,
    );
    _updateCookies(response);
    return response;
  }

  Future<http.Response> post(String url, dynamic data, {String? token}) async {
    final headers = _buildHeaders();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _client.post(
      Uri.parse(url),
      body: data,
      headers: headers,
    );
    _updateCookies(response);
    return response;
  }

  Map<String, String> _buildHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (cookies.isNotEmpty) {
      headers['Cookie'] = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    
    return headers;
  }

  void _updateCookies(http.Response response) {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      cookies['session'] = rawCookie.split(';')[0].split('=')[1];
    }
  }

  void clear() {
    cookies.clear();
  }
}