import 'package:flutter/material.dart';
import 'dart:math';
import 'package:ultimeet_v1/audio_player.dart';

class TalkTimeWidget extends StatelessWidget {
  final List<dynamic> userBreakPoints;
   final String? audioUrl;

  const TalkTimeWidget({super.key, required this.userBreakPoints, this.audioUrl});

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
            if (userBreakPoints.isEmpty)
              const Padding(padding: EdgeInsets.only(left: 2.0),
              child: Text(
                'No User Talk Time Found',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
              )
            else
            ...userBreakPoints.map((user) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: user['user_break_point_text'].map<Widget>((userText) {
                  String name = userText['name'];
                  double talkTime = userText['talk_time'];
                  String initials = getInitials(name);
                  Color avatarColor = getRandomColor();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
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
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: talkTime / 100,
                                  color:
                                      talkTime > 50 ? Colors.green : Colors.red,
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
            if (audioUrl != null)
              AudioPlayerWidget(audioUrl: audioUrl!),
          ],
        ),
      ),
    );
  }
}
