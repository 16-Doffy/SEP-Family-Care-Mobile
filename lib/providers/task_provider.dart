import 'package:flutter/material.dart';
import '../services/api_client.dart';

class TaskItem {
  final String id;
  final String title;
  final String status;
  final String assigneeName;

  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.assigneeName,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? json['name']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        assigneeName: json['assignee'] is Map
            ? (json['assignee'] as Map)['displayName']?.toString() ?? ''
            : '',
      );
}

class TaskProvider extends ChangeNotifier {
  List<TaskItem> _tasks = [];
  bool _loading = false;
  String? _error;

  List<TaskItem> get tasks => _tasks;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchTasks() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/tasks');
      final list = data is List
          ? data
          : data is Map && data['items'] is List
              ? data['items'] as List
              : <dynamic>[];
      _tasks = list
          .whereType<Map>()
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
