import 'package:flutter/material.dart';

class TaskManagementPage extends StatelessWidget {
  const TaskManagementPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Management')),
      body: const Center(
        child: Text('Task Management Page', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
