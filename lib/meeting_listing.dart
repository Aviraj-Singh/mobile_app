import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'api_service.dart';
import 'package:ultimeet_v1/meeting_minutes.dart';

class MeetingListingPage extends StatefulWidget {
  const MeetingListingPage({super.key});

  @override
  MeetingListingPageState createState() => MeetingListingPageState();
}

class MeetingListingPageState extends State<MeetingListingPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _meetings = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  String? _userId;
  String title = '';
  TextEditingController _searchController = TextEditingController(); // Controller for search bar
  FocusNode _searchFocusNode = FocusNode(); // FocusNode for the search bar

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  Future<void> _fetchUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('ACCESS_TOKEN');
    if (accessToken != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
      setState(() {
        _userId = decodedToken['user_id'].toString(); // Extract user ID
      });
      _fetchMeetings(); // Fetch meetings after userId is fetched
    }
  }

  Future<void> _fetchMeetings({bool resetPage = false}) async {
    if (_isLoading || !_hasMoreData && !resetPage) return;

    if (resetPage) {
      setState(() {
        _currentPage = 1;
        _meetings.clear();
        _hasMoreData = true;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getMeetingListing(
          _userId!, _currentPage, title); // Pass userId and current page
      final data = jsonDecode(response.body);

      if (data['success']) {
        setState(() {
          _meetings.addAll(data['data']);
          _hasMoreData = data['data'].length == 12; // Check if more data exists
          _currentPage++; // Increment page for next API call
        });
      } else {
        setState(() {
          _hasMoreData = false;
        });
      }
    } catch (e) {
      print('Error fetching meetings: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _unfocusSearch() {
    _searchFocusNode.unfocus(); // Unfocus the search bar when tapping outside
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocusSearch, // Tap anywhere to unfocus the search bar
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Text(
                'Your Meeting ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                'Facilitated by ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 18,
                ),
              ),
              Text(
                'UltiMeet',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode, // Attach the focus node
                decoration: InputDecoration(
                  hintText: 'Search meetings...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (query) {
                  setState(() {
                    title = query; // Update title with the search query
                  });
                  _fetchMeetings(resetPage: true); // Fetch meetings with new query
                },
              ),
            ),
            Expanded(
              child: _userId == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMeetingList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingList() {
    if (_meetings.isEmpty && !_isLoading) {
      if (title.isEmpty) {
        return const Center(
          child: Text("You don't have any meetings!"),
        );
      } else {
        return Center(
          child: Text('No Result Found for "$title"'),
        );
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isLoading &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _fetchMeetings(); // Load more meetings when scrolled to the bottom
        }
        return false;
      },
      child: ListView.builder(
        itemCount: _meetings.length + (_hasMoreData ? 1 : 0), // Add loader at the bottom
        itemBuilder: (context, index) {
          if (index == _meetings.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final meeting = _meetings[index];
          return _buildMeetingCard(meeting);
        },
      ),
    );
  }

  Widget _buildMeetingCard(dynamic meeting) {
    Color borderColor;

    switch (meeting['type']) {
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

    String title = meeting['title'] != null ? utf8.decode(meeting['title'].runes.toList()) : 'No Title';
    if (title.length > 100) {
      title = '${title.substring(0, 100)}...'; // Limit to 100 characters
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingMinutesPage(meetingId: meeting['id']),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 2.0), // Apply border color
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  '#${meeting['id']}',
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                Text(
                  'Organizer: ${meeting['organizer']['full_name']}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  'Schedule: ${meeting['schedule_date']} ${meeting['schedule_time']}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  'Location: ${meeting['location'] ?? 'Remote'}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  'Status: ${meeting['status']}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
