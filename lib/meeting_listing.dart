import 'package:flutter/material.dart';

class MeetingListingPage extends StatelessWidget {
  const MeetingListingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Listing')),
      body: const Center(
        child: Text('Meeting Listing', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
