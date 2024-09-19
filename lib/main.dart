import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'header.dart';
import 'meeting_listing.dart';
import 'dashboard.dart';
import 'create_meeting.dart';
//import 'task_management.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Widget _defaultPage = const CircularProgressIndicator();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('ACCESS_TOKEN');

    if (accessToken != null && accessToken.isNotEmpty) {
      setState(() {
        _defaultPage = const HomePage();  // User is logged in
      });
    } else {
      setState(() {
        _defaultPage = const LoginPage();  // User not logged in
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultimeet V1',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _defaultPage,  // Show either LoginPage or HomePage
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool isLoading = false;

  final List<Widget> _pages = [
    const DashboardPage(),
    const MeetingListingPage(),
    const CreateMeetingPage(),
    // const TaskManagementPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(70), // Ensures the header stays fixed
        child: Header(),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())  // Show loader
          : _pages[_selectedIndex], // Display the selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color.fromARGB(255, 19, 1, 64),  // Purple shade for selected items
        unselectedItemColor: Colors.grey,  // Grey for unselected items
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.meeting_room),
            label: 'Meeting Listings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create Meeting',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.task),
          //   label: 'Task Management',
          // ),
        ],
      ),
    );
  }
}
