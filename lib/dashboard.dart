import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'dart:convert';
import 'dart:math';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = true;
  List<dynamic> meetings = [];
  String? userName;

  @override
  void initState() {
    super.initState();
    _getUserDetails();
    fetchUpcomingMeetings();
  }

  Future<void> _getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('ACCESS_TOKEN');
    if (accessToken != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
      setState(() {
        userName = decodedToken['name'];
      });
    }
  }


  Future<void> fetchUpcomingMeetings() async {
    ApiService apiService = ApiService();
    try {
      final response = await apiService.getUpcomingMeetings();
      //print('Response Status Code: ${response.statusCode}');
      //print('Response Body: ${response.body}'); // Add this line for debugging
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data']['meeting_data'];
        setState(() {
          meetings = data;
          isLoading = false;
        });
      } else {
        // Handle error, e.g., show a message to the user
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      // Handle exception, e.g., show a message to the user
      print('Error: $e'); // Add this line for debugging
      setState(() {
        isLoading = false;
      });
    }
  }

  String getInitials(String name) {
    List<String> nameParts = name.split(' ');
    String initials = '';
    if (nameParts.isNotEmpty) {
      initials = nameParts[0][0];
      if (nameParts.length > 1) {
        initials += nameParts[1][0];
      }
    }
    return initials.toUpperCase();
  }

  Color getRandomColor() {
    final Random random = Random();
    // Generate a random color
    return Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome back, ${userName ?? 'User'}')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : meetings.isNotEmpty
              ? ListView.builder(
                  itemCount: meetings.length,
                  itemBuilder: (context, index) {
                    final meeting = meetings[index];
                    final participants = meeting['participant_list'];

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meeting['title'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${meeting['schedule_time']} - ${meeting['end_time']}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: participants.map<Widget>((participant) {
                                final String initials = getInitials(participant['name']);
                                final Color avatarColor = getRandomColor();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      initials,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : const Center(child: Text('No upcoming meetings')),
    );
  }
}
