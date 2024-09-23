import 'package:flutter/material.dart';
import 'api_service.dart'; // Import your api service

class MeetingMinutesPage extends StatefulWidget {
  final int meetingId;

  const MeetingMinutesPage({super.key, required this.meetingId});

  @override
  MeetingMinutesPageState createState() => MeetingMinutesPageState();
}

class MeetingMinutesPageState extends State<MeetingMinutesPage> {
  bool isLoading = true;
  Map<String, dynamic>? meetingData;
  ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    fetchMeetingData();
  }

  Future<void> fetchMeetingData() async {
    try {
      List<Map<String, dynamic>> data =
          await apiService.fetchMeetingData(widget.meetingId.toString());

      // Assign response data to variables (in order)
      if (data.length >= 13) {
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
            "additionalBreakPoints": data[12]
          };
          isLoading = false;
        });
      } else {
        // Handle the case where the response data is incomplete
        print('Error: Insufficient data received from API:');
        print(data);
        setState(() {
        isLoading = false;
      });
      }
    } catch (error) {
      print('Error fetching meeting data: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meeting ID: ${widget.meetingId}'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Meeting Details:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                    meetingData.toString()), // For now, just print all the data
                // You can add more UI here to properly display each data field
              ],
            ),
    );
  }
}
