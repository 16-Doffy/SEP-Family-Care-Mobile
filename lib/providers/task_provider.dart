import 'package:flutter/material.dart';
import '../services/api_client.dart';

class TaskItem {
  final String id;
  final String title;
  final String status;
  final String assigneeName;
  final String assigneeId;
  final double reward;

  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.assigneeName,
    required this.assigneeId,
    this.reward = 0,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? json['name']?.toString() ?? '',
        status: json['status']?.toString() ?? 'TODO',
        assigneeName: json['assignee'] is Map
            ? (json['assignee'] as Map)['displayName']?.toString() ?? ''
            : '',
        assigneeId: json['assigneeId']?.toString() ??
            (json['assignee'] is Map
                ? (json['assignee'] as Map)['id']?.toString() ?? ''
                : ''),
        reward: _parseDouble(json['reward'] ?? json['rewardAmount']),
      );

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class TaskProvider extends ChangeNotifier {
  List<TaskItem> _tasks = [];
  bool _loading = false;
  String? _error;

  List<TaskItem> get tasks => _tasks;
  bool get isLoading => _loading;
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

  Future<void> approveTask(String id, {required bool approved}) async {
    final status = approved ? 'DONE' : 'REJECTED';
    await ApiClient.instance.patch('/tasks/$id', {'status': status});
    await fetchTasks();
  }

  Future<void> createTask({
    required String title,
    String assigneeId = '',
    double reward = 0,
  }) async {
    await ApiClient.instance.post('/tasks', {
      'title': title,
      if (assigneeId.isNotEmpty) 'assigneeId': assigneeId,
      if (reward > 0) 'reward': reward,
    });
    await fetchTasks();
  }
}
