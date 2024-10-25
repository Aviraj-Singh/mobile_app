import 'package:flutter/material.dart';
import 'package:ultimeet_v1/audio_player.dart';
import 'api_service.dart';
import 'dart:convert';

class TalkTimeWidget extends StatefulWidget {
  final List<dynamic> userBreakPoints;
  final String? audioUrl;
  final Map<String, dynamic> meetingTranscription;
  final Function() onUpdate;

  const TalkTimeWidget({
    super.key,
    required this.userBreakPoints,
    required this.audioUrl,
    required this.meetingTranscription,
    required this.onUpdate,
  });

  @override
  TalkTimeWidgetState createState() => TalkTimeWidgetState();
}

class TalkTimeWidgetState extends State<TalkTimeWidget> {
  String? selectedSpeaker;

  Color getColorForUser(String name) {
    int hash = name.hashCode;
    return Color((hash & 0xFFFFFF) | 0xFF000000);
  }

  String getUpdatedName(String name) {
    if (name.contains(',')) {
      name = name.split(',')[0];
    }
    return name;
  }

  String getInitials(String name) {
    if (name.contains(',')) {
      name = name.split(',')[0];
    }
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

  void _showEditModal(BuildContext context, String name, String email, int id,
      int organisation, String rawTranscript) {
    TextEditingController nameController = TextEditingController(text: name);
    TextEditingController emailController = TextEditingController(text: email);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Participants'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Participant Name',
                ),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Participant Email',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedName = nameController.text;
                final updatedEmail = emailController.text;
                try {
                  List<dynamic> rawTranscriptArray = jsonDecode(rawTranscript);
                  for (var entry in rawTranscriptArray) {
                    if (entry['speaker'].contains(name)) {
                      entry['speaker'] = updatedName + ',' + updatedEmail;
                    }
                  }
                  ApiService apiService = ApiService();
                  final response = await apiService.updateTranscriptUser(
                    id,
                    updatedEmail,
                    updatedName.replaceAll(' ', '%20'),
                    organisation,
                    rawTranscriptArray,
                  );

                  if (response.statusCode == 200) {
                    // Success
                    widget.onUpdate();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Participant updated successfully!')),
                    );
                  } else {
                    // Handle error
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Failed to update participant: ${response.statusCode}')),
                    );
                    print(
                        'Failed to update participant: ${response.statusCode}');
                  }
                } catch (e) {
                  print(e);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error updating participant')),
                  );
                }

                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meeting Recording',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (widget.userBreakPoints.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 2.0),
                child: Text(
                  'No User Talk Time Found',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              )
            else
              ...widget.userBreakPoints.map((user) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      user['user_break_point_text'].map<Widget>((userText) {
                    String name = userText['name'];
                    String updatedName = getUpdatedName(name);
                    double talkTime = userText['talk_time'];
                    String initials = getInitials(name);
                    Color avatarColor = getColorForUser(name);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedSpeaker = name;
                              });
                            },
                            child: ClipOval(
                                child: Container(
                                    color: avatarColor,
                                    width: 40.0,
                                    height: 40.0,
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    updatedName,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 20,
                                      color:
                                          Color.fromARGB(255, 139, 139, 139)),
                                  onPressed: () {
                                    _showEditModal(
                                      context,
                                      name,
                                      '',
                                      widget.meetingTranscription['data'][0]
                                          ['id'],
                                      1,
                                      widget.meetingTranscription['data'][0]
                                          ['raw_transcript'],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: talkTime / 100,
                                    color: talkTime > 50
                                        ? Colors.green
                                        : Colors.red,
                                    backgroundColor: Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('${talkTime.toStringAsFixed(2)}%'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            const SizedBox(height: 20),
            if (widget.audioUrl != null)
              AudioPlayerWidget(
                audioUrl: widget.audioUrl!,
                userBreakPoints: widget.userBreakPoints,
                selectedSpeaker: selectedSpeaker ?? '',
              ),
          ],
        ),
      ),
    );
  }
}
