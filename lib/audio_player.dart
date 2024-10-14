import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final List<dynamic> userBreakPoints; // Pass the user breakpoints

  const AudioPlayerWidget(
      {super.key, required this.audioUrl, required this.userBreakPoints});

  @override
  AudioPlayerWidgetState createState() => AudioPlayerWidgetState();
}

class AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _audioPlayer.setUrl(widget.audioUrl);
      _audioPlayer.durationStream.listen((duration) {
        setState(() {
          totalDuration = duration ?? Duration.zero;
        });
      });
      _audioPlayer.positionStream.listen((position) {
        setState(() {
          currentPosition = position;
        });
      });
      _audioPlayer.playingStream.listen((playing) {
        setState(() {
          isPlaying = playing;
        });
      });
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  Future<void> _togglePlayPause() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  List<Widget> _buildBreakpoints() {
    List<Widget> markers = [];
    if (totalDuration.inMilliseconds > 0) {
      for (var user in widget.userBreakPoints) {
        List<dynamic> userBreakPointTexts = user['user_break_point_text'];

        for (var userBreakPoint in userBreakPointTexts) {
          String userName = userBreakPoint['name'];
          Color avatarColor = _getColorForUser(userName);

          List<dynamic> starts = userBreakPoint['start'];

          for (var start in starts) {
            if (start is double) {
              double positionPercent =
                  start.toDouble() / totalDuration.inMilliseconds.toDouble();

              markers.add(Align(
                alignment: Alignment(
                    (2 * positionPercent) - 1, 0), // Align marker horizontally
                child: GestureDetector(
                  onTap: () {
                    // Move the audio to this position when marker is tapped
                    _audioPlayer.seek(
                        Duration(milliseconds: start.toInt()));
                  },
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: avatarColor,
                    ),
                  ),
                ),
              ));
            } else {
              // Handle the case where start is not a double
              print('Warning: start value is not a double: ${start.runtimeType}');
            }
          }
        }
      }
    }
    return markers;
  }

  // Helper function to get color for user (same as in TalkTimeWidget)
  Color _getColorForUser(String name) {
    int hash = name.hashCode;
    return Color((hash & 0xFFFFFF) | 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _togglePlayPause,
            ),
            Text(
                '${currentPosition.inMinutes}:${(currentPosition.inSeconds % 60).toString().padLeft(2, '0')}'),
            const SizedBox(width: 10),
            Text(
                '${totalDuration.inMinutes}:${(totalDuration.inSeconds % 60).toString().padLeft(2, '0')}'),
          ],
        ),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Slider(
              min: 0.0,
              max: totalDuration.inSeconds.toDouble(),
              value: currentPosition.inSeconds.toDouble(),
              onChanged: (value) {
                setState(() {
                  _audioPlayer.seek(Duration(seconds: value.toInt()));
                });
              },
            ),
            // Add breakpoints on top of the slider
            Positioned.fill(
              child: Stack(
                children: _buildBreakpoints(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
