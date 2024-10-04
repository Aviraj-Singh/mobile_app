import 'package:flutter/material.dart';
import 'api_service.dart';

class ActionItemsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> actionItems;
  final List<Map<String, dynamic>> organisationData;
  final Map<String, dynamic> meetingDetails;
  final Function() onUpdate;

  const ActionItemsWidget({
    Key? key,
    required this.actionItems,
    required this.organisationData,
    required this.meetingDetails,
    required this.onUpdate,
  }) : super(key: key);

  @override
  ActionItemsWidgetState createState() => ActionItemsWidgetState();
}

class ActionItemsWidgetState extends State<ActionItemsWidget> {
  final ApiService apiService = ApiService();
  TextEditingController nameController = TextEditingController();
  TextEditingController assignedToController = TextEditingController();
  TextEditingController reporterController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  String priorityValue = 'MEDIUM';
  String statusValue = 'PENDING';
  DateTime? selectedDate;
  int? assignedToId;
  int? reporterId;

  List<Map<String, dynamic>> fetchedUsers = [];
  bool showSuggestions = false;
  bool isEditMode = false;
  int? editingItemId;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Action Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    _showAddItemModal(context);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text('Add Items'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            widget.actionItems.isEmpty
                ? const Text(
                    'There is no Action item present. If you want to create one, click on the add action item button.',
                    style: TextStyle(fontSize: 16),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 30,
                      headingRowColor:
                          MaterialStateProperty.all(Colors.grey[300]),
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
                      rows: widget.actionItems.map((item) {
                        return DataRow(cells: [
                          DataCell(
                            GestureDetector(
                              onTap: () {
                                _showToolbar(context, item);
                              },
                              child: Text(
                                _getTruncatedActionItemName(
                                    item['name']?.toString() ?? 'N/A'),
                              ),
                            ),
                          ),
                          DataCell(Text(
                              item['assigned_to']?['full_name']?.toString() ??
                                  '--')),
                          DataCell(Text(
                              item['reporter']?['full_name']?.toString() ??
                                  '--')),
                          DataCell(Text(
                              item['owner']?['full_name']?.toString() ??
                                  'N/A')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(
                                    item['priority']?.toString() ?? 'MEDIUM'),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item['priority']?.toString().isEmpty ?? true
                                    ? 'MEDIUM'
                                    : item['priority'].toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          DataCell(Text(item['due_on']?.toString() ?? 'N/A')),
                          DataCell(Text(item['status']?.toString() ?? 'N/A')),
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () {
                                  _showAddItemModal(context, item);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: () {
                                  _showDeleteConfirmation(context, item['id']);
                                },
                              ),
                            ],
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // Function to show the Add Item modal
  void _showAddItemModal(BuildContext context, [Map<String, dynamic>? item]) {
    if (item != null) {
      // Edit mode
      setState(() {
        isEditMode = true;
        editingItemId = item['id'];
        nameController.text = item['name'];
        assignedToController.text = item['assigned_to']?['full_name'] ?? '';
        assignedToId = item['assigned_to']?['id'];
        reporterController.text = item['reporter']?['full_name'] ?? '';
        reporterId = item['reporter']?['id'];
        priorityValue = item['priority'] ?? 'MEDIUM';
        dateController.text = item['due_on'] ?? '';
        selectedDate = DateTime.tryParse(item['due_on'] ?? '');
        statusValue = item['status'] ?? 'PENDING';
      });
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEditMode ? 'Edit Action Item' : 'Add Action Item',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildUserTextField(
                        assignedToController,
                        'Assigned to',
                        true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildUserTextField(
                          reporterController, 'Reporter', false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: priorityValue,
                        decoration:
                            const InputDecoration(labelText: 'Priority'),
                        items: ['HIGH', 'MEDIUM', 'LOW'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            priorityValue = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                            labelText: 'Due on',
                            suffixIcon: Icon(Icons.calendar_today)),
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                              dateController.text =
                                  "${selectedDate!.toLocal()}".split(' ')[0];
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: statusValue == 'PROGRESS' ? 'IN PROGRESS' : statusValue,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['COMPLETED', 'PENDING', 'IN PROGRESS', 'HOLD']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      statusValue = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final actionData = {
                          "assigned_to": assignedToId,
                          "end_date": dateController.text,
                          "meeting": widget.meetingDetails['id'],
                          "name": nameController.text,
                          "owner": widget.meetingDetails['organizer']['id'],
                          "priority": priorityValue,
                          "reporter": reporterId,
                          "status": statusValue == 'IN PROGRESS' ? 'PROGRESS' : statusValue,
                        };

                        print ('Action Data is: $actionData');
                        final response =
                            await apiService.updateActionItem(actionData);
                        if (response.statusCode == 200 || response.statusCode == 201) {
                          Navigator.pop(context);
                          widget.onUpdate();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Participant updated successfully!')),
                          );
                        } else {
                          // Handle error
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Failed to update participant: ${response.statusCode} - ${response.body}')),
                          );
                          print('Failed to update participant: ${response.statusCode} - ${response.body}');
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, int actionItemId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Action Item'),
          content: const Text('Do you want to delete this action item?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog without doing anything
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                final response =
                    await apiService.deleteActionItem(actionItemId);
                if (response.statusCode == 200 || response.statusCode == 201) {
                  Navigator.pop(context);
                  widget.onUpdate();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Action Item updated successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Failed to update action item: ${response.statusCode}')),
                  );
                  print('Failed to update action item: ${response.statusCode}');
                }
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserTextField(
      TextEditingController controller, String label, bool isAssignedTo) {
    return StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
            onChanged: (query) {
              if (query.isEmpty) {
                fetchedUsers.clear();
                showSuggestions = false;
              } else {
                setState(() {
                  // Filter organisationData based on query (matches name or email)
                  fetchedUsers = widget.organisationData.where((user) {
                    final nameLower = user['full_name'].toString().toLowerCase();
                    final emailLower = user['email'].toString().toLowerCase();
                    final queryLower = query.toLowerCase();
                    return nameLower.contains(queryLower) ||
                        emailLower.contains(queryLower);
                  }).toList();
                  // Show suggestions only if there are results
                  showSuggestions = fetchedUsers.isNotEmpty;
                });
              }
            },
          ),
          // Display the list of suggestions
          if (fetchedUsers.isNotEmpty && showSuggestions)
            SizedBox(
              height: 200, // Set a fixed height for the suggestion box
              child: ListView.builder(
                itemCount: fetchedUsers.length > 5 ? 5 : fetchedUsers.length,
                itemBuilder: (context, index) {
                  final user = fetchedUsers[index];
                  return ListTile(
                    title: Text(user['full_name']),
                    subtitle: Text(user['email']),
                    onTap: () {
                      setState(() {
                        if (isAssignedTo) {
                          assignedToController.text = user['full_name'];
                          assignedToId = user['id'];
                        } else {
                          reporterController.text = user['full_name'];
                          reporterId = user['id'];
                        }
                        fetchedUsers.clear();
                        showSuggestions = false;
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _selectUser(Map<String, dynamic> user, bool isAssignedTo) {
    setState(() {
      if (isAssignedTo) {
        assignedToController.text = user['full_name'];
        assignedToId = user['id'];
      } else {
        reporterController.text = user['full_name'];
        reporterId = user['id'];
      }
      fetchedUsers.clear();
      showSuggestions = false;
    });
  }

  // Helper function to truncate the action item name to 20 characters
  String _getTruncatedActionItemName(String name) {
    if (name.length > 20) {
      return '${name.substring(0, 20)}...';
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
              Text('${item['name']}'),
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
        return Colors.orange;
    }
  }
}
