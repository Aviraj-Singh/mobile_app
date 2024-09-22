import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://ultimeet-offline.ultimeet.io';

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('ACCESS_TOKEN', accessToken);
    await prefs.setString('REFRESH_TOKEN', refreshToken);
  }

  Future<String?> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('ACCESS_TOKEN');
  }

  Future<String?> getRefreshToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('REFRESH_TOKEN');
  }

  Future<void> clearTokens() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('ACCESS_TOKEN');
    await prefs.remove('REFRESH_TOKEN');
  }

  Future<http.Response> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/account/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return response;
  }

  Future<String> refreshAccessToken() async {
    String? refreshToken = await getRefreshToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );
    if (response.statusCode == 200) {
      String newAccessToken = jsonDecode(response.body)['access'];
      await saveTokens(newAccessToken, refreshToken!); // Save new access token
      return newAccessToken;
    } else {
      throw Exception('Failed to refresh token');
    }
  }

  Future<String> _getValidAccessToken() async {
    String? accessToken = await getAccessToken();

    // Check if the token is expired (simple logic; usually involves checking expiry timestamp)
    bool isTokenExpired = await _isTokenExpired(accessToken);

    if (isTokenExpired) {
      // Refresh the access token
      accessToken = await refreshAccessToken();
    }

    return accessToken!;
  }

  Future<bool> _isTokenExpired(String? token) async {
    if (token == null) return true;
    // Decode the JWT to check expiry (simplified example; in practice, check "exp" claim)
    final parts = token.split('.');
    if (parts.length != 3) return true;

    final payload = json
        .decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

    final expiry = payload['exp'];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return expiry < now;
  }

  Future<http.Response> getUserList(String organisation,
      {String searchString = '', bool me = false}) async {
    String accessToken = await _getValidAccessToken(); // Ensure token is valid

    final uri = Uri.parse(
      '$baseUrl/api/v1/users/?organisation=$organisation&search=$searchString${me ? '&me=true' : ''}',
    );

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) {
      // If access token is expired, refresh and retry
      accessToken = await refreshAccessToken();
      final retryHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final data = await http.get(uri, headers: retryHeaders);
      return data;
    }

    return response;
  }

  Future<http.Response> getUpcomingMeetings() async {
    String accessToken = await _getValidAccessToken();

    final uri = Uri.parse('$baseUrl/api/v1/dashboard/recent/upcomming_meetings?status=UPCOMMING&sync=true');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) {
      // If access token is expired, refresh and retry
      accessToken = await refreshAccessToken();
      final retryHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      return await http.get(uri, headers: retryHeaders);
    }

    return response;
  }

  Future<http.Response> createMeeting(Map<String, dynamic> meetingData) async {
    String accessToken = await _getValidAccessToken(); // Ensure token is valid

    final uri = Uri.parse('$baseUrl/api/v1/meeting/');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response =
        await http.post(uri, headers: headers, body: jsonEncode(meetingData));

    if (response.statusCode == 401) {
      // If access token is expired, refresh and retry
      accessToken = await refreshAccessToken();
      final retryHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      return await http.post(uri,
          headers: retryHeaders, body: jsonEncode(meetingData));
    }

    return response;
  }

  Future<http.Response> getMeetingListing(String userId, int page) async {
  String accessToken = await _getValidAccessToken();

  final uri = Uri.parse(
    '$baseUrl/api/v1/users/$userId/meetings/?size=12&page=$page&title=&type=&location=&date=',
  );
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  final response = await http.get(uri, headers: headers);

  if (response.statusCode == 401) {
    accessToken = await refreshAccessToken();
    final retryHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    return await http.get(uri, headers: retryHeaders);
  }

  return response;
}

}
