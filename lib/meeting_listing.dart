import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'api_service.dart';  // Import your ApiService class

class MeetingListingPage extends StatefulWidget {
  const MeetingListingPage({super.key});

  @override
  MeetingListingPageState createState() => MeetingListingPageState();
}

class MeetingListingPageState extends State<MeetingListingPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _meetings = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  Future<void> _fetchUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('ACCESS_TOKEN');
    if (accessToken != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
      setState(() {
        _userId = decodedToken['user_id'].toString(); // Extract user ID
      });
      _fetchMeetings(); // Fetch meetings after userId is fetched
    }
  }

  Future<void> _fetchMeetings() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getMeetingListing(
          _userId!, _currentPage); // Pass userId and current page
      final data = jsonDecode(response.body);

      if (data['success']) {
        setState(() {
          _meetings.addAll(data['data']);
          _hasMoreData = data['data'].length == 12; // Check if more data exists
          _currentPage++; // Increment page for next API call
        });
      }
    } catch (e) {
      print('Error fetching meetings: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Listing')),
      body: _userId == null
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!_isLoading &&
                    scrollInfo.metrics.pixels ==
                        scrollInfo.metrics.maxScrollExtent) {
                  _fetchMeetings(); // Load more meetings when scrolled to the bottom
                }
                return false;
              },
              child: ListView.builder(
                itemCount: _meetings.length + (_hasMoreData ? 1 : 0), // Add loader at the bottom
                itemBuilder: (context, index) {
                  if (index == _meetings.length) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final meeting = _meetings[index];
                  return _buildMeetingCard(meeting);
                },
              ),
            ),
    );
  }

  Widget _buildMeetingCard(dynamic meeting) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meeting['title'] ?? 'No Title',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Organizer: ${meeting['organizer']['full_name']}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              'Schedule: ${meeting['schedule_date']} ${meeting['schedule_time']}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              'Location: ${meeting['location'] ?? 'Remote'}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              'Status: ${meeting['status']}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
