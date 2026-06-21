import 'package:flutter/material.dart';
import '../services/api_client.dart';

class TaskItem {
  final String id;
  final String assignmentId; // có khi response là assignment object
  final String title;
  final String description;
  final String status;
  final String assigneeName;
  final String assigneeId;
  final double reward;
  final bool isRecurring;
  final String? categoryName;
  final String? dueDate;

  const TaskItem({
    required this.id,
    this.assignmentId = '',
    required this.title,
    this.description = '',
    required this.status,
    required this.assigneeName,
    required this.assigneeId,
    this.reward = 0,
    this.isRecurring = false,
    this.categoryName,
    this.dueDate,
  });

  // Parse both Task objects and Assignment-wrapping-Task objects
  factory TaskItem.fromJson(Map<String, dynamic> json) {
    // assignment response wraps task in 'task' field
    final task = json['task'] is Map
        ? Map<String, dynamic>.from(json['task'] as Map)
        : json;
    final isAssignment = json['task'] is Map;

    final assignee = task['assignee'] is Map ? task['assignee'] as Map : {};
    final rewardSetting = task['rewardSetting'] is Map ? task['rewardSetting'] as Map : {};
    final category = task['category'] is Map ? task['category'] as Map : {};

    return TaskItem(
      id: task['id']?.toString() ?? '',
      assignmentId: isAssignment ? json['id']?.toString() ?? '' : '',
      title: task['title']?.toString() ?? task['name']?.toString() ?? '',
      description: task['description']?.toString() ?? '',
      // assignment status takes priority (PENDING/SUBMITTED/APPROVED/etc)
      status: (isAssignment ? json['status'] : task['status'])?.toString() ?? 'TODO',
      assigneeName: assignee['displayName']?.toString() ?? '',
      assigneeId: task['assigneeId']?.toString() ?? assignee['id']?.toString() ?? '',
      reward: _parseDouble(rewardSetting['rewardAmount'] ?? task['reward'] ?? task['rewardAmount']),
      isRecurring: task['isRecurring'] as bool? ?? false,
      categoryName: category['name']?.toString() ?? task['categoryName']?.toString(),
      dueDate: task['dueDate']?.toString() ?? json['dueDate']?.toString(),
    );
  }

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class TaskProvider extends ChangeNotifier {
  String? _familyId;
  List<TaskItem> _tasks = [];
  bool _loading = false;
  String? _error;

  List<TaskItem> get tasks => _tasks;
  bool get isLoading => _loading;
  String? get error => _error;

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchTasks();
    }
  }

  Future<void> fetchTasks({String? status, String? assigneeId}) async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (assigneeId != null) params['assigneeId'] = assigneeId;
      final data = await ApiClient.instance.get(
        '/families/$_familyId/tasks',
        params: params.isEmpty ? null : params,
      );
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

  Future<void> fetchMyAssignments() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$_familyId/tasks/my-assignments');
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

  Future<void> createTask({
    required String title,
    String description = '',
    String assigneeId = '',
    double reward = 0,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$_familyId/tasks', {
      'title': title,
      if (description.isNotEmpty) 'description': description,
      if (assigneeId.isNotEmpty) 'assigneeId': assigneeId,
    });
    await fetchTasks();
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> body) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch('/families/$_familyId/tasks/$taskId', body);
    await fetchTasks();
  }

  // Shortcut cho task_management_screen: duyệt / từ chối task
  Future<void> approveTask(String taskId, {required bool approved}) async {
    await updateTask(taskId, {'status': approved ? 'DONE' : 'REJECTED'});
  }

  Future<void> cancelTask(String taskId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch('/families/$_familyId/tasks/$taskId/cancel');
    await fetchTasks();
  }

  // Submit completion proof for an assignment
  Future<void> submitCompletion(String assignmentId, {String? note}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/assignments/$assignmentId/submissions',
      {if (note != null && note.isNotEmpty) 'note': note},
    );
  }

  // Manager reviews a submission
  Future<void> reviewSubmission(String submissionId, {required bool approved, String? note}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/submissions/$submissionId/review',
      {
        'decision': approved ? 'APPROVE' : 'REJECT',
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    await fetchTasks();
  }

  // Assign task to a member
  Future<void> assignTask(String taskId, String memberId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/$taskId/assignments',
      {'memberId': memberId},
    );
    await fetchTasks();
  }
}
