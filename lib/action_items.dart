import 'package:flutter/material.dart';

class ActionItemsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> actionItems;

  const ActionItemsWidget({Key? key, required this.actionItems}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4, // Add some elevation for shadow effect
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // Rounded corners
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Add some padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Action Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Enable horizontal scrolling
              child: DataTable(
                columnSpacing: 30,
                headingRowColor: MaterialStateProperty.all(Colors.grey[300]), // Set header color
                columns: const [
                  DataColumn(label: Text('Action Item')),
                  DataColumn(label: Text('Assigned to')),
                  DataColumn(label: Text('Reporter')),
                  DataColumn(label: Text('Owner')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Due on')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: actionItems.map((item) {
                  return DataRow(cells: [
                    DataCell(
                      GestureDetector(
                        onTap: () {
                          _showToolbar(context, item);
                        },
                        child: Text(
                          _getTruncatedActionItemName(item['name']?.toString() ?? 'N/A'),
                        ),
                      ),
                    ), // Action Item with restriction
                    DataCell(Text(item['assigned_to']?['full_name']?.toString() ?? '--')), // Assigned to
                    DataCell(Text(item['reporter']?['full_name']?.toString() ?? '--')), // Reporter
                    DataCell(Text(item['owner']?['full_name']?.toString() ?? 'N/A')), // Display specific owner field
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(item['priority']?.toString() ?? ''),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item['priority']?.toString() ?? 'N/A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ), // Priority with color
                    DataCell(Text(item['due_on']?.toString() ?? 'N/A')), // Due on
                    DataCell(Text(item['status']?.toString() ?? 'N/A')), // Status
                    DataCell(Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () {
                            // Handle edit action
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () {
                            // Handle delete action
                          },
                        ),
                      ],
                    )), // Actions (edit/delete icons)
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to truncate the action item name to 20 characters
  String _getTruncatedActionItemName(String name) {
    if (name.length > 20) {
      return '${name.substring(0, 20)}...'; // Truncate and add ellipsis
    }
    return name;
  }

  // Helper function to show a toolbar with additional actions
  void _showToolbar(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${item['name']}'), // Show full name
            ],
          ),
        );
      },
    );
  }

  // Helper function to determine the color for priority labels
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
