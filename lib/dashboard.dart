import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'dart:convert';
import 'dart:math';
import 'instant_meeting.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = true;
  List<dynamic> meetings = [];
  String? userName;
  String? organizer;
  String? organization;
  String? organizationName;
  String? department;
  final _meetingLinkController = TextEditingController();

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
        organizer = decodedToken['user_id'].toString();
        organization = decodedToken['organization']['id'].toString();
        organizationName = decodedToken['organization']['name'];
        department = decodedToken['department']['id'].toString();
      });
    }
  }

  Future<void> fetchUpcomingMeetings() async {
    ApiService apiService = ApiService();
    try {
      final response = await apiService.getUpcomingMeetings();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data']['meeting_data'];
        setState(() {
          meetings = data;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
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

  String _convertTimeToUTC(DateTime dateTime) {
    return DateFormat.Hms().format(dateTime.toUtc());
  }

  void _openInstantMeetingModal(
      List<dynamic> participants, String meetingId) async {
    bool? shouldRefresh = await showDialog(
      context: context,
      builder: (context) => InstantMeetingModal(
        participants: participants,
        meetingId: meetingId,
        organizer: organizer!,
        organization: organization!,
        department: department!,
        organizationName: organizationName!,
      ),
    );

    if (shouldRefresh == true) {
      fetchUpcomingMeetings();
    }
  }

  Future<void> _createMeeting() async {
    final String meetingLink = _meetingLinkController.text.trim();
    if (meetingLink.isEmpty) {
      Fluttertoast.showToast(
        msg: "Meeting link is required",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    DateTime currentTime = DateTime.now();
    final meetingData = {
      'meeting_link': meetingLink,
      'start_time': _convertTimeToUTC(currentTime),
      'schedule_date': DateFormat('yyyy-MM-dd').format(currentTime),
      'organizer': organizer,
      'organization': organization,
      'department': department,
      'title': '$userName Ultimeet\'s meeting',
      'schedule_time': _convertTimeToUTC(currentTime),
      'type': 'Team',
      'description':
          '$userName meeting on ${DateFormat('yyyy-MM-dd').format(currentTime)}',
      'location': 'Remote',
      'duration': '10',
      'end_time': _convertTimeToUTC(currentTime.add(Duration(minutes: 10))),
    };

    try {
      ApiService apiService = ApiService();
      final response = await apiService.createMeeting(meetingData);
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        Fluttertoast.showToast(
          msg: "Your bot will be sent to the meeting",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        _meetingLinkController.clear();
        FocusScope.of(context).unfocus();
        fetchUpcomingMeetings();
      } else {
        Fluttertoast.showToast(
          msg: responseData['error'] ?? "Meeting creation failed",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error creating meeting: $e');
      Fluttertoast.showToast(
        msg: "An error occurred. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _createInstantMeeting() async {
    DateTime currentTime = DateTime.now();
    final meetingData = {
      'organizer': organizer,
      'organization': organization,
      'department': department,
      'title': '$userName\'s meeting on ${DateFormat('yyyy-MM-dd HH:mm:ss').format(currentTime)} (UTC)',
      'schedule_date': DateFormat('yyyy-MM-dd').format(currentTime),
      'schedule_time': _convertTimeToUTC(currentTime),
      'start_time': _convertTimeToUTC(currentTime),
      'type': 'Instant',
      'description': '$userName\'s meeting on ${DateFormat('yyyy-MM-dd HH:mm:ss').format(currentTime)} (UTC)',
      'location': 'Offline',
      'duration': '10',
      'end_time': _convertTimeToUTC(currentTime.add(const Duration(minutes: 10))),
    };

    try {
      ApiService apiService = ApiService();
      final response = await apiService.createMeeting(meetingData);
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        final meetingId = responseData['data']['id'].toString();
        _openInstantMeetingModal([], meetingId);
      } else {
        // Handle failure
        Fluttertoast.showToast(
          msg: responseData['error'] ?? "Meeting creation failed",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error creating meeting: $e');
      Fluttertoast.showToast(
        msg: "An error occurred. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Color getMeetingTypeColor(String meetingType) {
    Color borderColor;

    switch (meetingType) {
      case "Board":
        borderColor = const Color(0xFFDCA600); // #DCA600
        break;
      case "Agile":
        borderColor = const Color(0xFF3B8D1F); // #3B8D1F
        break;
      case "Customer meeting":
        borderColor = const Color(0xFF006BDE); // #006BDE
        break;
      case "Team":
        borderColor = const Color(0xFFFF8000); // #FF8000
        break;
      case "Sales meeting":
        borderColor = const Color(0xFFFF0000); // #F00
        break;
      default:
        borderColor = Colors.grey; // Default border color if no type matches
    }
    return borderColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              const Text(
                'Welcome back, ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                userName ?? 'User',
                style:
                    const TextStyle(fontStyle: FontStyle.italic, fontSize: 18),
              ),
            ],
          ),
          actions: [
            Padding(
              padding:
                  const EdgeInsets.only(right: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: _createInstantMeeting,
                child: const Text(
                  "Instant Meeting",
                  style: TextStyle(
                      color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Send Instant Bot",
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _meetingLinkController,
                            decoration: InputDecoration(
                              hintText: 'Enter Meeting Link',
                              prefixIcon: const Icon(Icons.link),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _createMeeting,
                          child: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 24.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            backgroundColor: Colors.blue, // Button color
                            foregroundColor: Colors.white, // Text color
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : meetings.isNotEmpty
                      ? ListView.builder(
                          itemCount: meetings.length,
                          itemBuilder: (context, index) {
                            final meeting = meetings[index];
                            final participants = meeting['participant_list'];
                            final Color cardBorderColor = getMeetingTypeColor(meeting['type']);

                            return GestureDetector(
                              onTap: () {
                                // Open modal with the participant list and meeting ID
                                _openInstantMeetingModal(
                                    participants, meeting['id'].toString());
                              },
                              child: Card(
                                margin: const EdgeInsets.all(8.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  side: BorderSide(color: cardBorderColor, width: 2.0),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meeting['title'],
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '#${meeting['id']}',
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${meeting['schedule_time']} - ${meeting['end_time']}',
                                        style:
                                            const TextStyle(color: Colors.black),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: participants
                                            .map<Widget>((participant) {
                                          final String initials =
                                              getInitials(participant['name']);
                                          final Color avatarColor =
                                              getRandomColor();
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: CircleAvatar(
                                              radius: 20,
                                              backgroundColor: avatarColor,
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : const Center(child: Text('No upcoming meetings')),
            )
          ],
        ));
  }
}
