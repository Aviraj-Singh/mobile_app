import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class MeetingOverview extends StatelessWidget {
  final Map<String, dynamic> meetingAnalytics;

  const MeetingOverview({Key? key, required this.meetingAnalytics})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverallHealth(),
            const SizedBox(height: 20),
            _buildMetric(
              'Attendance Metric',
              meetingAnalytics['attendance_metric'].toString() + '%',
              Icons.check_circle_outline,
              Colors.green,
            ),
            const SizedBox(height: 20),
            _buildMetric(
              'Participation Engagement',
              meetingAnalytics['participation_engagement'].toStringAsFixed(2) +
                  '%',
              Icons.person_outline,
              Colors.green,
            ),
            const SizedBox(height: 20),
            _buildMetric(
              'Reaction Analytics',
              meetingAnalytics['reaction_analytics'].toString() + '%',
              Icons.insert_emoticon_outlined,
              Colors.grey,
            ),
            const SizedBox(height: 20),
            _buildSentimentAnalytics(),
            const SizedBox(height: 20),
            // _buildMetric(
            //   'Language Monitoring',
            //   '${meetingAnalytics['language_monitoring'].toString()}%',
            //   Icons.language,
            //   Colors.green,
            // ),
            _buildLanguageMonitoring(),
            const SizedBox(height: 20),
            _buildActionItemDetails(),
            const SizedBox(height: 20),
            _buildSustainabilityIndex(),
          ],
        ),
      ),
    );
  }

  Widget _buildSustainabilityIndex() {
  double sustainableIndex = meetingAnalytics['sustainable_index'];

  return Card(
    elevation: 4,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sustainability Index',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 150,
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    ranges: <GaugeRange>[
                      GaugeRange(
                        startValue: 0,
                        endValue: 33,
                        color: Colors.orange,
                      ),
                      GaugeRange(
                        startValue: 33,
                        endValue: 66,
                        color: Colors.yellow,
                      ),
                      GaugeRange(
                        startValue: 66,
                        endValue: 100,
                        color: Colors.green,
                      ),
                    ],
                    pointers: <GaugePointer>[
                      NeedlePointer(value: sustainableIndex)
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        widget: Text(
                          '$sustainableIndex%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        positionFactor: 0.5,
                        angle: 90,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildOverallHealth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Meeting Health',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                value: meetingAnalytics['overall_health_score'] / 100,
                strokeWidth: 8,
                backgroundColor: Colors.grey[300],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
              ),
              Text(
                '${meetingAnalytics['overall_health_score'].toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageMonitoring() {
    double languageMonitoring = meetingAnalytics['language_monitoring'];
    String status = _getLanguageMonitoringStatus(languageMonitoring);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Icon(Icons.language, color: Colors.green),
          const SizedBox(width: 10),
          const Text('Language Monitoring', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(
            '${languageMonitoring.toStringAsFixed(0)}% $status',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // Get language monitoring status (Excellent, Good, Poor)
  String _getLanguageMonitoringStatus(double score) {
    if (score > 80) {
      return 'Excellent';
    } else if (score >= 50) {
      return 'Good';
    } else {
      return 'Poor';
    }
  }

  Widget _buildMetric(
      String title, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSentimentAnalytics() {
    var sentiment = meetingAnalytics['sentiment_analytics'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sentiment Analytics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildSentimentItem('Positive', '${sentiment['positive']}%', Colors.green),
            const SizedBox(width: 15),
            _buildSentimentItem('Negative', '${sentiment['negative']}%', Colors.red),
            const SizedBox(width: 15),
            _buildSentimentItem('Neutral', '${sentiment['neutral']}%', Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildSentimentItem(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildActionItemDetails() {
    var actionItems = meetingAnalytics['action_item_details'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Action Item Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        _buildActionItemRow('Completed', actionItems['completed_action_items'], actionItems['total_action_items']),
        _buildActionItemRow('Pending', actionItems['pending_action_items'], actionItems['total_action_items']),
        _buildActionItemRow('In progress', actionItems['in_progress_action_items'], actionItems['total_action_items']),
        _buildActionItemRow('On hold', actionItems['on_hold_action_items'], actionItems['total_action_items']),
      ],
    );
  }

  Widget _buildActionItemRow(String label, int count, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text('${count.toString()}/${total.toString()}', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
