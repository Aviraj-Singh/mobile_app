import 'package:flutter/material.dart';
import 'api_service.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultimeet_v1/talk_time.dart';
import 'package:ultimeet_v1/meeting_details.dart';
import 'package:ultimeet_v1/action_items.dart';
import 'package:ultimeet_v1/meeting_overview.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

const String baseUrl = 'https://ultimeet-offline.ultimeet.io';

class MeetingMinutesPage extends StatefulWidget {
  final int meetingId;

  const MeetingMinutesPage({super.key, required this.meetingId});

  @override
  MeetingMinutesPageState createState() => MeetingMinutesPageState();
}

class MeetingMinutesPageState extends State<MeetingMinutesPage> {
  bool isLoading = true;
  Map<String, dynamic>? meetingData;
  String? audioUrl;
  ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    fetchMeetingData();
  }

  Future<void> fetchMeetingData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? accessToken = prefs.getString('ACCESS_TOKEN');
      if (accessToken != null) {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
        String organizationName = decodedToken['organization']['name'] ?? "";
        List<Map<String, dynamic>> data =
            await apiService.fetchMeetingData(widget.meetingId.toString(), organizationName);

        // Assign response data to variables (in order)
        if (data.length >= 13) {
          String? audioUrlFromData = data[0]['data']["audio"];
          String token = await _getAccessToken();
          if (audioUrlFromData != null && token.isNotEmpty) {
            audioUrl =
                '$baseUrl$audioUrlFromData?key=${token.replaceAll("\"", "")}&meeting_id=${widget.meetingId.toString()}';
          }
          setState(() {
            meetingData = {
              "meetingDetails": data[0],
              "meetingDecision": data[1],
              "meetingAnalytics": data[2],
              "userBreakPoints": data[3],
              "meetingTranscription": data[4],
              "meetingDependency": data[5],
              "meetingAnnouncement": data[6],
              "actionItems": data[7],
              "sustainableActionItems": data[8],
              "attachments": data[9],
              "meetingNotes": data[10],
              "meetingSummary": data[11],
              "additionalBreakPoints": data[12],
              "organizationData": data[13],
            };
            isLoading = false;
          });
        } else {
          // Handle the case where the response data is incomplete
          print('Error: Insufficient data received from API');
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (error) {
      print('Error fetching meeting data: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String> _getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('ACCESS_TOKEN');
    return accessToken ?? '';
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

  Color _getBorderColor(String type) {
    switch (type) {
      case "Board":
        return const Color(0xFFDCA600);
      case "Agile":
        return const Color(0xFF3B8D1F);
      case "Customer meeting":
        return const Color(0xFF006BDE);
      case "Team":
        return const Color(0xFFFF8000);
      case "Sales meeting":
        return const Color(0xFFFF0000);
      default:
        return Colors.grey; // Default border color if no match
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(meetingData != null
            ? meetingData!['meetingDetails']!['data']!["title"] ?? 'Meeting'
            : 'Meeting ID: ${widget.meetingId}'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 300, // Set fixed height for the container
                      child: _buildCardWithBorder(),
                    ),
                    const SizedBox(height: 20),
                    if (meetingData!['userBreakPoints']!['data'] != null)
                      TalkTimeWidget(
                        userBreakPoints:
                            meetingData!['userBreakPoints']!['data'],
                        audioUrl: audioUrl!,
                        meetingTranscription:
                            meetingData!['meetingTranscription'],
                        onUpdate: fetchMeetingData,
                      ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height - 300,
                          child: MeetingDetailsTabs(
                            meetingDecision: meetingData!['meetingDecision'],
                            meetingSummary: meetingData!['meetingSummary'],
                            meetingTranscription:
                                meetingData!['meetingTranscription'],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ActionItemsWidget(
                        actionItems: List<Map<String, dynamic>>.from(
                            meetingData!["actionItems"]["data"] ?? []),
                        organisationData: List<Map<String, dynamic>>.from(
                            meetingData!["organizationData"]["data"] ?? []),
                        meetingDetails: Map<String, dynamic>.from(meetingData!["meetingDetails"]["data"] ?? []),
                        onUpdate: fetchMeetingData,
                        ),
                    const SizedBox(height: 20),
                    MeetingOverview(
                        meetingAnalytics: meetingData!['meetingAnalytics']
                            ['data']),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCardWithBorder() {
    // Extract the type from the meetingData
    String meetingType =
        meetingData?['meetingDetails']?['data']?["type"] ?? 'N/A';

    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _getBorderColor(meetingType), width: 1.0),
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMeetingDetails(),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildOrganizerSection()),
                const SizedBox(width: 10),
                Expanded(child: _buildParticipantsSection()),
              ],
            ),
            const SizedBox(height: 20),
            _buildActionItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            meetingData != null
                ? meetingData!['meetingDetails']!['data']!["title"] ?? 'Meeting'
                : 'Meeting ID: ${widget.meetingId}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Text('# ${widget.meetingId}'),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 10),
            Text(
              meetingData?['meetingDetails']?['data']?["schedule_date"] ??
                  "N/A",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 10),
            Text(
              meetingData?['meetingDetails']?['data']?["schedule_time"] ??
                  "N/A",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 15),
            Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 10),
                Text(
                  meetingData?["location"] ?? "Offline",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            )
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantsSection() {
    List participants =
        meetingData?['meetingDetails']?['data']?['participant_list'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Participants',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: participants.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 7.0),
                      child: Text(
                        'None',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0;
                              i <
                                  (participants.length > 2
                                      ? 2
                                      : participants.length);
                              i++)
                            _buildParticipantAvatar(participants[i]),
                          if (participants.length > 2)
                            GestureDetector(
                              onTap: () =>
                                  _showParticipantsDialog(participants),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  '+${participants.length - 2}', // Number of additional participants
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantAvatar(Map<String, dynamic> participant) {
    final String initials = getInitials(participant['name']);
    final Color avatarColor = getRandomColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: avatarColor,
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showParticipantsDialog(List participants) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Participants',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    final String initials = getInitials(participant['name']);
                    final Color avatarColor = getRandomColor();
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarColor,
                        child: Text(
                          initials,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(participant['name']),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrganizerSection() {
    var organizer = meetingData?['meetingDetails']?['data']?["organizer"] ?? {};
    final String initials = getInitials(organizer['full_name']);
    final Color avatarColor = getRandomColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organizer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarColor,
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizer["full_name"] ?? "N/A",
                  style: const TextStyle(fontSize: 16),
                ),
                // Text(
                //   organizer["email"] ?? "N/A", // Null check with fallback
                //   style: const TextStyle(fontSize: 12, color: Colors.grey),
                // ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItems() {
    var actionItems =
        meetingData?['meetingDetails']?["data"]?['action_items'] ?? {};

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          '${actionItems["total_action_items"] ?? 0} action items',
          style: TextStyle(
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 10),
        const Icon(
          Icons.circle,
          color: Colors.red,
          size: 10,
        ),
        const SizedBox(width: 5),
        Text('Open ${actionItems["not_completed"] ?? 0}'),
        const SizedBox(width: 10),
        const Icon(
          Icons.circle,
          color: Colors.green,
          size: 10,
        ),
        const SizedBox(width: 5),
        Text('Closed ${actionItems["completed"] ?? 0}'),
      ],
    );
  }
}
