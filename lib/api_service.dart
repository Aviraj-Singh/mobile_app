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

    final uri = Uri.parse(
        '$baseUrl/api/v1/dashboard/recent/upcomming_meetings?status=UPCOMMING&sync=true');
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

  Future<http.Response> getMeetingListing(String userId, int page, String title) async {
    String accessToken = await _getValidAccessToken();

    final uri = Uri.parse(
      '$baseUrl/api/v1/users/$userId/meetings/?size=12&page=$page&title=$title&type=&location=&date=',
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

  Future<http.Response> _getApiData(String endpoint) async {
    String accessToken = await _getValidAccessToken();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) {
      // Handle token refresh and retry if needed
      accessToken = await refreshAccessToken();
      final retryHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      return await http.get(uri, headers: retryHeaders);
    }

    return response;
  }

  Future<List<Map<String, dynamic>>> fetchMeetingData(String meetingId, String organizationName) async {
    // List of all the API endpoints
    List<String> endpoints = [
      '/api/v1/meeting/$meetingId/',
      '/api/v1/meeting/$meetingId/meeting_decision/',
      '/api/v1/meetings/$meetingId/analytics/',
      '/api/v1/meeting/$meetingId/meeting_user_break_points/',
      '/api/v1/meeting/$meetingId/meeting_transcription/',
      '/api/v1/meeting/$meetingId/meeting_dependency/',
      '/api/v1/meeting/$meetingId/meeting_announcement/',
      '/api/v1/meeting/$meetingId/meeting_actionitem/',
      '/api/v1/meeting/$meetingId/meeting_actionitem/?sustainable=true',
      '/api/v1/meeting/$meetingId/meeting_attachment/',
      '/api/v1/meeting/$meetingId/meeting_notes/',
      '/api/v1/meeting/$meetingId/meeting_summary/',
      '/api/v1/meeting/$meetingId/meeting_user_break_points/',
      '/api/v1/users/?organisation=&search=&me=true',
    ];

    // Fetch data from all endpoints in parallel
    List<Future<http.Response>> futures = endpoints.map((endpoint) => _getApiData(endpoint)).toList();

    List<http.Response> responses = await Future.wait(futures);

    List<Map<String, dynamic>> decodedResponses = [];

  for (var response in responses) {
    if (response.statusCode == 200) {
      try {
        // Try parsing the JSON response
        final decoded = jsonDecode(response.body);
        decodedResponses.add(decoded as Map<String, dynamic>);
      } catch (e) {
        print('Error parsing JSON for endpoint: ${response.request?.url}');
        print('Response body: ${response.body}');
      }
    } else {
      print('Error: ${response.statusCode} from ${response.request?.url}');
      print('Response body: ${response.body}');
    }
  }

    return decodedResponses;
  }

  Future<http.Response> updateTranscriptUser(int id, String email, String name, int organisation, List<dynamic> rawTranscriptArray) async {
  String accessToken = await _getValidAccessToken();

  final uri = Uri.parse('$baseUrl/api/v1/edit/transcript-user/?id=$id&email=$email&organisation=$organisation');
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  final body = jsonEncode({
    'raw_transcript': rawTranscriptArray,
  });

  print('Body is: $body');

  final response = await http.patch(uri, headers: headers, body: body);

  if (response.statusCode == 401) {
    accessToken = await refreshAccessToken();
    final retryHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    return await http.post(uri, headers: retryHeaders, body: body);
  }

  return response;
}

Future<http.Response> updateActionItem(Map<String, dynamic> actionData) async {
  String accessToken = await _getValidAccessToken(); // Ensure token is valid

  final uri = Uri.parse('$baseUrl/api/v1/task/action-item/');
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  final body = jsonEncode(actionData);

  final response = await http.post(uri, headers: headers, body: body);

  if (response.statusCode == 401) {
    // If access token is expired, refresh and retry
    accessToken = await refreshAccessToken();
    final retryHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    return await http.post(uri, headers: retryHeaders, body: body);
  }

  return response;
}

Future<http.Response> deleteActionItem(int id) async {
  String accessToken = await _getValidAccessToken(); // Ensure token is valid

  final uri = Uri.parse('$baseUrl/api/v1/task/action-item/$id/');
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  final response = await http.delete(uri, headers: headers);

  if (response.statusCode == 401) {
    // If access token is expired, refresh and retry
    accessToken = await refreshAccessToken();
    final retryHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    return await http.delete(uri, headers: retryHeaders);
  }

  return response;
}


}
