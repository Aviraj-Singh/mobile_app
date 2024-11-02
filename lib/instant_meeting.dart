import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class InstantMeetingModal extends StatefulWidget {
  final List<dynamic> participants;
  final String meetingId;
  final String organizer;
  final String organization;
  final String department;
  final String organizationName;

  const InstantMeetingModal({
    Key? key,
    required this.participants,
    required this.meetingId,
    required this.organizer,
    required this.organization,
    required this.department,
    required this.organizationName,
  }) : super(key: key);

  @override
  _InstantMeetingModalState createState() => _InstantMeetingModalState();
}

class _InstantMeetingModalState extends State<InstantMeetingModal> {
  TextEditingController _participantsController = TextEditingController();
  final ApiService apiService = ApiService();
  DateTime _currentDateTime = DateTime.now();
  List<dynamic> participants = [];
  List<String> participantsList = [];
  List<Map<String, dynamic>> fetchedUsers = [];
  List<Map<String, dynamic>> selectedUsers = [];
  bool showSuggestions = false;
  bool isPaused = false;
  File? audioFile;
  bool isAttachment = false;
  String startTime = '';
  String endTime = '';
  String? _audioFilePath;
  //new items
  late AudioRecorder recorder;
  late AudioPlayer player;
  bool fileExists = false;
  bool isRecording = false;
  bool isPlaying = false;
  bool fileExist = false;
  String recordedAudioPath = '';
  String uploadedFilePath = '';
  String uploadedAttachmentFilePath = '';
  Source url = UrlSource('');
  var audiofile;
  bool processing = false;
  bool recorderPaused = false;
  final stopwatch = Stopwatch();
  Timer? _timer;
  String timePassed = '';
  String finalDuration = '';

  @override
  void initState() {
    super.initState();
    participants = widget.participants;
    participantsList = widget.participants
        .map((participant) => participant['id'].toString())
        .toList();
    player = AudioPlayer();
    recorder = AudioRecorder();
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

  // Function to add user from selectedUsers and participantsList
  void _selectUser(Map<String, dynamic> user) {
    print('User is: $user');
    setState(() {
      //participants.add(user);
      participantsList.add(user['id'].toString());
      selectedUsers.add(user);
      _participantsController.clear();
      fetchedUsers.clear();
      showSuggestions = false;
    });
  }

  // Function to remove user from selectedUsers and participantsList
  void _removeUser(Map<String, dynamic> user) {
    setState(() {
      //participants.remove(user);
      participantsList.remove(user['id'].toString());
      selectedUsers.remove(user);
    });
  }

  @override
  void dispose() {
    _participantsController.dispose();
    player.dispose();
    recorder.dispose();
    uploadedFilePath = '';
    uploadedAttachmentFilePath = '';
    recordedAudioPath = '';
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _checkAndRequestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    // Check if microphone permission is granted
    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      print('Recording Permission Denied');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Microphone permission is required to record audio.')),
      );
      return;
    }

    // Check if storage permission is granted (for Android versions needing explicit permission)
    if (Platform.isAndroid) {
      if (statuses[Permission.storage] != PermissionStatus.granted &&
          Platform.isAndroid &&
          (await Permission.storage.status.isDenied)) {
        print('Storage Permission Denied');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Storage permission is required to store audio.')),
        );
        return;
      }

      // For Android 11+ (API level 30 and above)
      if (Platform.isAndroid &&
          await Permission.manageExternalStorage.isDenied) {
        print('External Storage Permission Denied');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Manage external storage permission is required.')),
        );
        return;
      }
    }
  }

  Future<void> pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      uploadedFilePath = result.files.single.path!;
      setState(() {
        processing = true;
      });
    } else {
      // User canceled the picker
    }
  }

  Future<void> pickAttachmentAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      uploadedAttachmentFilePath = result.files.single.path!;
      setState(() {
        processing = true;
      });
    } else {
      // User canceled the picker
    }
  }

  void removeAudioFile() {
    setState(() {
      uploadedFilePath = '';
      processing = false;
    });
    //update();
  }

  void removeAttachmentAudioFile() {
    setState(() {
      uploadedFilePath = '';
      processing = false;
    });
  }

  void pauseRecording() {
    debugPrint("pauseRecording() called");

    setState(() {
      player.pause();
      recorder.pause();
      stopwatch.stop();
      _timer?.cancel();
      isPlaying = false;
      recorderPaused = true;
    });
  }

  void resumeRecording() {
    debugPrint("resumeRecording() called");
    player.resume();
    recorder.resume();
    stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!stopwatch.isRunning) t.cancel();
      setState(() {
        timePassed = stopwatch.elapsed.inSeconds.toString();
      });
    });
    setState(() {
      recorderPaused = false;
    });
  }

  deleteRecording() async {
    try {
      File file = File(recordedAudioPath);
      if (await file.exists()) {
        player.stop();
        await file.delete();
        setState(() {
          fileExists = false;
          recordedAudioPath = '';
        });

        Fluttertoast.showToast(
            msg: 'Recording Deleted',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white);
      }
    } catch (e) {
      print('error in deleteRecording $e');
    }
    setState(() {
      fileExists = false;
    });
  }

  startRecording() async {
    await _checkAndRequestPermission();
    if (await Permission.microphone.isDenied &&
        await Permission.manageExternalStorage.isDenied) {
      print('Cannot start recording, permission denied');
      return;
    }
    try {
      setState(() {
        isRecording = true;
      });
      WakelockPlus.enable();
      stopwatch.start();
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!stopwatch.isRunning) t.cancel();
        setState(() {
          timePassed = stopwatch.elapsed.inSeconds.toString();
        });
      });
      if (await recorder.hasPermission()) {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String appDocPath = appDocDir.path;
        recordedAudioPath = '$appDocPath/recording.m4a';
        await recorder.start(const RecordConfig(), path: recordedAudioPath);
        setState(() {
          isRecording = true;
          fileExists = true;
        });
      } else {
        print('no permission');
      }
    } catch (e) {
      print('error in startRecording $e');
    }
  }

  stopRecording() async {
    try {
      setState(() {
        isRecording = false;
        processing = true;
        recorderPaused = false;
      });
      WakelockPlus.disable();
      finalDuration = formatTime(timePassed);
      stopwatch.stop();
      stopwatch.reset();
      String? path = await recorder.stop();
      recordedAudioPath = path!;
      debugPrint('audioPath: $recordedAudioPath');
    } catch (e) {
      debugPrint('error in stopRecording $e');
    }
  }

  void playRecording(String path) {
    try {
      url = UrlSource(path);
      player.play(url);
      setState(() {
        isPlaying = true;
      });
      player.onPlayerComplete.listen((event) {
        setState(() {
          isPlaying = false;
        });
      });
    } catch (e) {
      debugPrint('error in playRecording() $e');
    }
  }

  Future<void> deleteMeeting() async {
    final response = await apiService.deleteMeeting(widget.meetingId);
    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting Deleted Successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete meting: ${response.statusCode}')),
      );
      print('Failed to delete meting: ${response.statusCode}');
    }
  }

  Future<void> _uploadAudioFile() async {
    if (recorderPaused) {
      Fluttertoast.showToast(
        msg: 'Please stop the recording before saving.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    participantsList = participantsList.toSet().toList();

    print('Uploaded Path: $uploadedFilePath');
    print('Recorded Path: $recordedAudioPath');

    final fileLimitMB = 250;

    if (uploadedFilePath.isNotEmpty) {
      final uploadedFile = File(uploadedFilePath);
      final uploadedFileSizeMB = await uploadedFile.length() / (1024 * 1024);
      print('File size is: $uploadedFileSizeMB');
      if (uploadedFileSizeMB > fileLimitMB) {
        Fluttertoast.showToast(
          msg: 'Uploaded file exceeds the 250MB limit.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
    }

    if (recordedAudioPath.isNotEmpty) {
      final recordedFile = File(recordedAudioPath);
      final recordedFileSizeMB = await recordedFile.length() / (1024 * 1024);
      print('File size is: $recordedFileSizeMB');
      if (recordedFileSizeMB > fileLimitMB) {
        Fluttertoast.showToast(
          msg: 'Recorded audio file exceeds the 250MB limit.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
    }

    var data = {
      'meeting': widget.meetingId,
      'participant_list': participantsList,
    };
    if (uploadedFilePath.isNotEmpty || recordedAudioPath.isNotEmpty) {
      try {
        final response = await apiService.uploadAudio(
          meetingId: widget.meetingId,
          uploadedFilePath: uploadedFilePath,
          recordedAudioPath: recordedAudioPath,
          selectedUserIds: participantsList,
        );
        if (response.statusCode == 200) {
          print('Audio uploaded successfully!');
          Fluttertoast.showToast(
            msg: 'Meeting Audio and Participants updated successfully!',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          await apiService.addParticipantsInMeeting(data);
          await apiService.getAudioProcessing(widget.meetingId);
          Navigator.of(context).pop(true);
        } else {
          print('Failed to upload audio: ${response.statusCode}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error uploading audio. Please try again.')),
          );
        }
      } catch (e) {
        print('Error uploading audio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error uploading audio, Please try again.')),
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: 'No audio file to upload',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      print('No audio file to upload');
    }
  }

  Future<void> _fetchUsers() async {
    final searchString = _participantsController.text;
    if (searchString.isNotEmpty) {
      try {
        final response = await apiService.getUserList(widget.organizationName,
            searchString: searchString);
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final List<dynamic> users = responseData['data'];
          //final List<dynamic> users = jsonDecode(response.body);
          setState(() {
            fetchedUsers =
                users.map((user) => user as Map<String, dynamic>).toList();
            showSuggestions = fetchedUsers.isNotEmpty;
          });
        } else {
          print('Failed to fetch users: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching users: $e');
      }
    } else {
      setState(() {
        showSuggestions = false; // Hide dropdown if no input
      });
    }
  }

  String formatTime(String seconds) {
    if (seconds.isEmpty) {
      return '00:00:00';
    }
    int sec = int.parse(seconds);
    int hours = sec ~/ 3600;
    int minutes = (sec ~/ 60) % 60;
    sec = sec % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Instant Meeting",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: deleteMeeting,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text("Meeting Controls",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isRecording ? stopRecording : startRecording,
                      icon: Icon(
                          isRecording ? Icons.stop : Icons.fiber_manual_record),
                      label: Text(
                          isRecording ? "Stop Recording" : "Start Recording"),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                            isRecording ? Colors.red : Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      isRecording ? formatTime(timePassed) : '',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (isRecording && !recorderPaused)
                      ElevatedButton.icon(
                        onPressed: pauseRecording,
                        icon: const Icon(Icons.pause),
                        label: const Text("Pause"),
                      ),
                    if (recorderPaused)
                      ElevatedButton.icon(
                        onPressed: resumeRecording,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Resume"),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text("or"),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: pickAudioFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Upload Audio File"),
                ),
                const SizedBox(height: 16),
                if (processing &&
                    (uploadedFilePath.isNotEmpty ||
                        recordedAudioPath.isNotEmpty))
                  Column(
                    children: [
                      Text(
                        uploadedFilePath.isNotEmpty
                            ? 'Selected File: ${uploadedFilePath.split('/').last}'
                            : '',
                      ),
                      recordedAudioPath.isNotEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment
                                  .spaceEvenly, // Adjust alignment here
                              children: [
                                Text(
                                    'Duration: $finalDuration'), // Format the final duration
                                IconButton(
                                  icon: Icon(isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow),
                                  onPressed: () {
                                    playRecording(recordedAudioPath);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: deleteRecording,
                                ),
                              ],
                            )
                          : const Text(''),
                      // recordedAudioPath.isNotEmpty
                      //     ? const Text('Press to Delete Recording')
                      //     : const Text(''),
                    ],
                  ),
                Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),
                    Text(DateFormat.yMMMMd().format(_currentDateTime)),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time),
                    const SizedBox(width: 8),
                    Text(DateFormat.jm().format(_currentDateTime)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Note: If you are removing the participants, they will be marked as absentees.",
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text("Participants",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: participants.map((user) {
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topRight,
                      children: [
                        CircleAvatar(
                          child: Text(getInitials(user['name'] ?? '')),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _participantsController,
                  decoration: const InputDecoration(
                    labelText: "Add Participants (Email/Name/Department)",
                    hintText: 'Enter participant name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _fetchUsers(),
                ),
                const SizedBox(height: 16),
                if (fetchedUsers.isNotEmpty && showSuggestions)
                  Column(
                    children: fetchedUsers.take(2).map((user) {
                      return ListTile(
                        title: Text('${user['full_name']}'),
                        subtitle: Text('${user['email']}'),
                        onTap: () => _selectUser(user),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: selectedUsers.map((user) {
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topRight,
                      children: [
                        CircleAvatar(
                          child: Text(getInitials(user['full_name'] ?? '')),
                        ),
                        Positioned(
                          right: -8,
                          top: -8,
                          child: GestureDetector(
                            onTap: () => _removeUser(user),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await _uploadAudioFile();
                        //await _downloadAudioFile();
                      },
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
