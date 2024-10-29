import 'dart:convert';
import 'package:flutter/material.dart';

class MeetingDetailsTabs extends StatelessWidget {
  final Map<String, dynamic> meetingDecision;
  final Map<String, dynamic> meetingTranscription;
  final Map<String, dynamic> meetingSummary;

  const MeetingDetailsTabs({
    Key? key,
    required this.meetingDecision,
    required this.meetingTranscription,
    required this.meetingSummary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meeting Details'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelPadding: EdgeInsets.symmetric(horizontal: 4.0),
            tabs: [
              Tab(text: "Summary"),
              Tab(text: "Important Point"),
              Tab(text: "Transcript"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSummaryTab(),
            _buildDecisionTab(),
            _buildTranscriptTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    var summaryData = meetingSummary['data'];
    if (summaryData != null && summaryData.isNotEmpty) {
      String summaryTextString = summaryData[0]['summary_text'];
      List<dynamic> summaryTexts =
          summaryTextString.isNotEmpty ? jsonDecode(summaryTextString) : [];

      if (summaryTexts.isNotEmpty) {
        String formattedSummary =
            summaryTexts.map((text) => _cleanText(text)).join("\n\n");

        return _buildCardWithContent(
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(formattedSummary),
          ),
        );
      }
    }

    return _buildCardWithContent(
      const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No summary available'),
      ),
    );
  }

  Widget _buildDecisionTab() {
    var decisionData = meetingDecision['data'];
    if (decisionData != null && decisionData.isNotEmpty) {
      String decisionTextString = decisionData[0]['decision_text'];
      List<dynamic> decisionTexts =
          decisionTextString.isNotEmpty ? jsonDecode(decisionTextString) : [];

      if (decisionTexts.isNotEmpty) {
        String formattedDecision =
            decisionTexts.map((text) => _cleanText(text)).join("\n\n");

        return _buildCardWithContent(
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(formattedDecision),
          ),
        );
      }
    }

    return _buildCardWithContent(
      const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No decision available'),
      ),
    );
  }

  Widget _buildTranscriptTab() {
    var transcriptData = meetingTranscription['data'];
    if (transcriptData != null && transcriptData.isNotEmpty) {
      String transcriptString = transcriptData[0]['raw_transcript'];
      List<dynamic> rawTranscript =
          transcriptString.isNotEmpty ? jsonDecode(transcriptString) : [];

      if (rawTranscript.isNotEmpty) {
        return _buildCardWithContent(
          ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: rawTranscript.length,
            itemBuilder: (context, index) {
              final transcriptEntry = rawTranscript[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transcriptEntry['speaker'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(_cleanText(transcriptEntry['text'])),
                  const Divider(),
                ],
              );
            },
          ),
        );
      }
    }

    return _buildCardWithContent(
      const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No transcript available'),
      ),
    );
  }

  Widget _buildCardWithContent(Widget content) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: content,
      ),
    );
  }

  String _cleanText(String text) {
    final cleanedText = text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(r'\\n', '\n') // Convert \n to actual newlines
        .replaceAll(r'\\u2019', '\'') // Replace encoded apostrophes
        .replaceAll(RegExp(r'[\\#*]+'), '') // Remove all backslashes, #, and *
        .replaceAll(
            RegExp(r'\"'), '"'); // Replace escaped quotes with actual quotes

    return cleanedText.trim(); // Trim any leading/trailing whitespace
  }
}
