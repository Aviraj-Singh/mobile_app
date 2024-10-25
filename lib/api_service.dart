import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
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

  Future<http.Response> getMeetingListing(
      String userId, int page, String title) async {
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

  Future<List<Map<String, dynamic>>> fetchMeetingData(
      String meetingId, String organizationName) async {
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
    List<Future<http.Response>> futures =
        endpoints.map((endpoint) => _getApiData(endpoint)).toList();

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

  Future<http.Response> updateTranscriptUser(int id, String email, String name,
      int organisation, List<dynamic> rawTranscriptArray) async {
    String accessToken = await _getValidAccessToken();

    final uri = Uri.parse(
        '$baseUrl/api/v1/edit/transcript-user/?id=$id&email=$email&organisation=$organisation');
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

  Future<http.Response> updateActionItem(
      Map<String, dynamic> actionData) async {
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

  Future<http.StreamedResponse> editActionItem(
      Map<String, dynamic> actionData, String itemId) async {
    String accessToken = await _getValidAccessToken(); // Ensure token is valid

    final uri = Uri.parse('$baseUrl/api/v1/task/action-item/$itemId/');

    final request = http.MultipartRequest('PATCH', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';

    // Add each field in actionData to the multipart request
    actionData.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    final response = await request.send();

    if (response.statusCode == 401) {
      // If access token is expired, refresh and retry
      accessToken = await refreshAccessToken();
      request.headers['Authorization'] = 'Bearer $accessToken';
      return await request.send();
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

  Future<http.Response> uploadMedia({
    required String meetingID,
    required File mediaFile,
    required String startTime,
    required String endTime,
    required List<String> participantsList,
    required bool isSafariBrowser,
  }) async {
    String accessToken = await _getValidAccessToken();
    final uri = Uri.parse(
        '$baseUrl/api/v1/meeting/$meetingID/media${isSafariBrowser ? "?browser=SAFARI" : ""}');

    // Guess the media file's MIME type
    final mimeTypeData =
        lookupMimeType(mediaFile.path)?.split('/') ?? ['audio', 'wav'];

    Uint8List fileBytes = await mediaFile.readAsBytes();
    var request = http.MultipartRequest('PATCH', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Content-Type'] = 'multipart/form-data'
      ..fields['start_time'] = startTime
      ..fields['end_time'] = endTime;

    for (String participantID in participantsList) {
      request.fields['participants_list'] = participantID;
    }

    request.files.add(http.MultipartFile.fromBytes(
      'audio',
      fileBytes,
      filename: mediaFile.path.split('/').last,
      contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
    ));

    final response = await request.send();
    return await http.Response.fromStream(response);
  }

  Future<http.StreamedResponse> uploadAudio({
    required String meetingId,
    required String uploadedFilePath,
    required String recordedAudioPath,
    required List<String> selectedUserIds,
  }) async {
    // Get access token
    String accessToken = await _getValidAccessToken();

    // Set headers
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    print("headers: $headers");

    // Create a MultipartFile using the audio path (either uploaded or recorded)
    final audioFile = await http.MultipartFile.fromPath(
      'audio',
      uploadedFilePath.isNotEmpty ? uploadedFilePath : recordedAudioPath,
    );

    // Create a MultipartRequest
    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse('$baseUrl/api/v1/meeting/$meetingId/media/'),
    );

    print('url: $baseUrl/api/v1/meeting/$meetingId/media/');

    // Add headers to the request
    request.headers.addAll(headers);

    // Add other fields (start_time, end_time, participants_list)
    request.fields.addAll({
      'start_time': DateTime.now().toString().substring(11, 16),
      'end_time': DateTime.now()
          .add(const Duration(minutes: 10))
          .toString()
          .substring(11, 16),
      'participants_list': selectedUserIds.join(','),
    });

    // Attach the audio file to the request
    request.files.add(audioFile);

    // Send the request
    final response = await request.send();

    print('response of uploadAudio(): ${response.statusCode}');

    // Handle success and retry logic if necessary
    if (response.statusCode == 401) {
      accessToken = await refreshAccessToken();
      request.headers['Authorization'] = 'Bearer $accessToken';

      final retryResponse = await request.send();
      return retryResponse;
    }

    return response;
  }

  Future<http.Response> getAudioProcessing(
    String meetingID,
  ) async {
    String accessToken = await _getValidAccessToken();

    final uri = Uri.parse(
        'https://ultimeet-transcript.ultimeet.io/api/v1/generate_transcript/?meeting_id=$meetingID');
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

  Future<http.Response> deleteMeeting(String id) async {
    String accessToken = await _getValidAccessToken(); // Ensure token is valid

    final uri = Uri.parse('$baseUrl/api/v1/meeting/$id/');
    //https://ultimeet-offline.ultimeet.io/api/v1/meeting/36433/
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

  Future<http.Response> addParticipantsInMeeting(
      Map<String, dynamic> data) async {
    String accessToken = await _getValidAccessToken();

    final uri = Uri.parse('$baseUrl/api/v1/meeting-participants/');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response =
        await http.post(uri, headers: headers, body: jsonEncode(data));

    if (response.statusCode == 401) {
      // If access token is expired, refresh and retry
      accessToken = await refreshAccessToken();
      final retryHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      return await http.post(uri,
          headers: retryHeaders, body: jsonEncode(data));
    }
    print(response.body);
    print(response.statusCode);

    return response;
  }
}
