import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'api_service.dart';
import 'dart:convert';
import 'package:ultimeet_v1/main.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CreateMeetingPage(),
    );
  }
}

class CreateMeetingPage extends StatefulWidget {
  const CreateMeetingPage({super.key});

  @override
  CreateMeetingPageState createState() => CreateMeetingPageState();
}

class CreateMeetingPageState extends State<CreateMeetingPage> {
  final ApiService apiService = ApiService();
  DateTime selectedDate = DateTime.now();
  DateTime? recurrentEndDate;
  TimeOfDay selectedTime = TimeOfDay.now();
  String selectedMeetingType = 'Team';
  String location = 'Offline';
  int duration = 30;
  List<String> participantsList = [];
  List<Map<String, dynamic>> fetchedUsers = [];
  List<Map<String, dynamic>> selectedUsers = [];
  String? agendaFile;
  String? meetingLink;
  String repeatEvery = 'None';
  String organizer = '';
  String organization = '1';
  String firstName = '';
  bool showSuggestions = false;

  // Dropdown options
  final List<String> durations = ['15', '30', '45', '60'];
  final List<String> repeatOptions = ['None', 'Daily', 'Weekly', 'Monthly'];
  final List<Map<String, String>> meetingTypes = [
    {'name': "Board Meeting", 'type': "Board"},
    {'name': "Agile Meeting", 'type': "Agile"},
    {'name': "Customer Meeting", 'type': "Customer meeting"},
    {'name': "Team Status", 'type': "Team"},
    {'name': "Sales Meeting", 'type': "Sales meeting"},
  ];

  // Text controllers for meeting name, agenda, and meeting link
  final _meetingNameController = TextEditingController();
  final _meetingAgendaController = TextEditingController();
  final _meetingLinkController = TextEditingController(); // For online meetings
  final _participantsController = TextEditingController(); // For participants

  @override
  void initState() {
    super.initState();
    _initializeTimeZones();
    _loadUserDetails();
    _participantsController.addListener(_fetchUsers);
  }

  Future<void> _initializeTimeZones() async {
    await Future.delayed(Duration.zero, () {
      tzdata.initializeTimeZones();
    });
  }

  @override
  void dispose() {
    _meetingNameController.dispose();
    _meetingAgendaController.dispose();
    _meetingLinkController.dispose(); // Dispose of meeting link controller
    _participantsController.dispose(); // Dispose of participants controller
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Fetch access token from SharedPreferences
    String? accessToken = prefs.getString('ACCESS_TOKEN');

    if (accessToken != null) {
      try {
        // Decode the token
        Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);

        // Extract user details
        String? firstName = decodedToken['name'];
        String? userId = decodedToken['user_id'].toString();

        if (firstName != null && userId != null) {
          setState(() {
            this.firstName = firstName;
            this.organizer = userId;
            _meetingNameController.text = '$firstName Ultimeet\'s meeting';
            _meetingAgendaController.text =
                '$firstName Ultimeet\'s meeting agenda';
          });
        } else {
          // Handle missing user details
          print('Missing user details in token');
        }
      } catch (e) {
        // Handle decoding error
        print('Error decoding token: $e');
      }
    } else {
      // Handle case where access token is not found
      print('Access token not found');
    }
  }

  Future<void> _fetchUsers() async {
    final searchString = _participantsController.text;
    if (searchString.isNotEmpty) {
      try {
        final response = await apiService.getUserList('IntellAI',
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
          print('Users fetched: $fetchedUsers');
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
    setState(() {
      participantsList.add(user['id'].toString());
      selectedUsers.add(user);
      print('This is participant list: $participantsList');
      print('This is selected user list $selectedUsers');
      _participantsController.clear();
      fetchedUsers.clear();
      showSuggestions = false;
    });
  }

  // Function to remove user from selectedUsers and participantsList
  void _removeUser(Map<String, dynamic> user) {
    setState(() {
      participantsList.remove(user['id'].toString());
      selectedUsers.remove(user);
      print('This is participant list: $participantsList');
      print('This is selected user list $selectedUsers');
    });
  }

  // Function to select a date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // Function to select a time
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  // Function to select an agenda file
  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        agendaFile = result.files.single.name;
      });
    }
  }

  // Function to select an end date for recurring meetings
  Future<void> _selectRecurrentEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        recurrentEndDate = picked;
      });
    }
  }

  // Calculate end time based on duration
  TimeOfDay calculateEndTime() {
    final int totalMinutes =
        selectedTime.hour * 60 + selectedTime.minute + duration;
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  // Convert the selected time to UTC
  String _convertTimeToUTC(TimeOfDay time, DateTime date) {
    final tz.Location local =
        tz.getLocation('Asia/Kolkata'); // Assuming UTC+5:30
    final localDateTime = tz.TZDateTime(
        local, date.year, date.month, date.day, time.hour, time.minute);
    final utcDateTime = localDateTime.toUtc();
    return DateFormat.Hms()
        .format(utcDateTime); // Convert to UTC in HH:mm:ss format
  }

  // Helper function to validate if any field in meetingData is empty or null
  bool _validateMeetingData(Map<String, dynamic> data) {
    for (var entry in data.entries) {
      var value = entry.value;

      // Check if the value is null, an empty string, or an empty list
      if (value == null ||
          (value is String && value.isEmpty) ||
          (value is List && value.isEmpty)) {
        _showToast('Field "${entry.key}" is required.');
        print('Field "${entry.key}" is required.');
        return false;
      }
    }
    return true;
  }

  // Function to show toast message
  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // Display the selected data when the meeting is created
  void _createMeeting() async{
    final endTime = calculateEndTime();

    // Update meeting link before creating the meeting
    if (location == 'Online') {
      meetingLink = _meetingLinkController.text;
    }

    final meetingData = {
      'start_time': _convertTimeToUTC(selectedTime, selectedDate),
      'schedule_date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'organizer': organizer,
      'organization': organization,
      'department': 1,
      'title': _meetingNameController.text,
      'schedule_time': _convertTimeToUTC(selectedTime, selectedDate),
      'type': selectedMeetingType, // Use 'type' here
      'description': _meetingAgendaController.text,
      'location': location == 'Online' ? 'Remote' : location,
      'duration': duration.toString(),
      'end_time': _convertTimeToUTC(endTime, selectedDate),
      'end_date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'participants_list': participantsList,
    };

    if (repeatEvery != 'None') {
      meetingData['repeat'] = repeatEvery;
      meetingData['recurrent_end_date'] = recurrentEndDate != null
          ? DateFormat('yyyy-MM-dd').format(recurrentEndDate!)
          : DateFormat('yyyy-MM-dd').format(DateTime.now());
      //meetingData['recurrent_end_date'] = DateFormat('yyyy-MM-dd').format(recurrentEndDate!);
    }

    if (location != 'Offline') {
      meetingData['meeting_link'] = meetingLink.toString();
    }

    // Validate the meetingData before proceeding
    if (_validateMeetingData(meetingData)) {
      // If all fields are valid, print the meetingData
      print(meetingData);
      try {
        // Call the API service
        final response = await apiService.createMeeting(meetingData);
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the meeting creation was successful
        if (responseData['success'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          // Show toaster with error message
          Fluttertoast.showToast(
              msg: responseData['error'] ?? 'Meeting creation failed.',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white);
        }
      } catch (e) {
        // Handle any errors
        print('Error creating meeting: $e');
        Fluttertoast.showToast(
            msg: 'An error occurred. Please try again.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Meeting')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Meeting Name
            TextField(
              controller: _meetingNameController,
              decoration: const InputDecoration(
                labelText: 'Meeting Name *',
              ),
            ),
            const SizedBox(height: 16),

            // Meeting Agenda
            TextField(
              controller: _meetingAgendaController,
              decoration: const InputDecoration(
                labelText: 'Meeting Agenda *',
              ),
            ),
            const SizedBox(height: 16),

            // Upload Agenda File
            ElevatedButton(
              onPressed: _selectFile,
              child: Text(agendaFile != null ? agendaFile! : 'Select Files'),
            ),
            const SizedBox(height: 16),

            // Meeting Type
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Meeting Type *'),
              value: selectedMeetingType,
              items: meetingTypes.map((Map<String, String> type) {
                return DropdownMenuItem<String>(
                  value: type['type'],
                  child: Text(type['name']!),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  selectedMeetingType = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: const Text('Select Date'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Time: ${selectedTime.format(context)}'),
                ElevatedButton(
                  onPressed: () => _selectTime(context),
                  child: const Text('Select Time'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Duration
            DropdownButtonFormField<String>(
              decoration:
                  const InputDecoration(labelText: 'Duration (minutes) *'),
              value: duration.toString(),
              items: durations.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  duration = int.parse(newValue!);
                });
              },
            ),
            const SizedBox(height: 16),

            // Repeat Every Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Repeat Every'),
              value: repeatEvery,
              items: repeatOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  repeatEvery = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),

            // End Date for recurring meetings (visible only when repeatEvery is not None)
            if (repeatEvery != 'None')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'End Date: ${DateFormat('yyyy-MM-dd').format(recurrentEndDate ?? selectedDate)}'),
                  ElevatedButton(
                    onPressed: () => _selectRecurrentEndDate(context),
                    child: const Text('Select End Date'),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Meeting Location
            DropdownButtonFormField<String>(
              decoration:
                  const InputDecoration(labelText: 'Meeting Location *'),
              value: location,
              items: ['Offline', 'Online'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  location = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Meeting Link (Visible only if location is Online)
            if (location == 'Online')
              TextField(
                controller: _meetingLinkController,
                decoration: const InputDecoration(
                  labelText: 'Online Meeting Link *',
                ),
              ),
            const SizedBox(height: 16),

            // Add Participants
            TextField(
              controller: _participantsController,
              decoration: const InputDecoration(
                labelText: 'Add Participants',
                hintText: 'Invite through email / name',
              ),
            ),
            const SizedBox(height: 8),

            if (fetchedUsers.isNotEmpty && showSuggestions)
              Column(
                children: fetchedUsers.take(5).map((user) {
                  return ListTile(
                    title: Text('${user['full_name']}'),
                    subtitle: Text('${user['email']}'),
                    onTap: () => _selectUser(user),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // Display selected participants with CircleAvatar
            Wrap(
              spacing: 8,
              children: selectedUsers.map((user) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment
                      .topRight, // Align the cross button to top-right of the avatar
                  children: [
                    CircleAvatar(
                      child: Text(getInitials(user['full_name'] ?? '')),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      child: GestureDetector(
                        onTap: () => _removeUser(
                            user), // Function to remove the participant
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
            const SizedBox(height: 24),

            // Create Meeting Button
            ElevatedButton(
              onPressed: _createMeeting,
              child: const Text('Create Meeting'),
            ),
          ],
        ),
      ),
    );
  }
}
