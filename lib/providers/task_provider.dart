import 'package:flutter/material.dart';
import '../services/api_client.dart';

// UC38 = AD_HOC  (tự phát, 1 lần)
// UC39 = RECURRING (định kỳ có khung giờ, bắt buộc có người thực hiện)
enum TaskType { adHoc, recurring }

// UC46/47 — Trạng thái thanh toán phần thưởng
// PENDING       = chưa duyệt xong
// AWAITING      = đã duyệt, chờ manager xác nhận đã trả thưởng
// SETTLED       = đã thanh toán (manager xác nhận)
// CONFIRMED     = member xác nhận nhận được thưởng
// DISPUTED      = member báo chưa nhận được
enum RewardStatus { pending, awaiting, settled, confirmed, disputed }

class TaskItem {
  final String id;
  final String title;
  final String status;
  final String assigneeName;
  final String assigneeId;
  final double reward;
  final TaskType type;
  final String? schedule;
  final RewardStatus rewardStatus;

  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.assigneeName,
    required this.assigneeId,
    this.reward = 0,
    this.type = TaskType.adHoc,
    this.schedule,
    this.rewardStatus = RewardStatus.pending,
  });

  bool get isRecurring => type == TaskType.recurring;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? '').toUpperCase();
    final taskType = typeStr.contains('RECURRING')
        ? TaskType.recurring
        : TaskType.adHoc;

    final assignee = json['assignee'] is Map
        ? (json['assignee'] as Map)
        : <String, dynamic>{};

    final rsStr = (json['rewardStatus'] as String? ?? '').toUpperCase();
    final rs = switch (rsStr) {
      'AWAITING'  => RewardStatus.awaiting,
      'SETTLED'   => RewardStatus.settled,
      'CONFIRMED' => RewardStatus.confirmed,
      'DISPUTED'  => RewardStatus.disputed,
      _           => RewardStatus.pending,
    };

    return TaskItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'TODO',
      assigneeName: assignee['displayName']?.toString() ?? '',
      assigneeId: json['assigneeId']?.toString() ??
          assignee['id']?.toString() ?? '',
      reward: _parseDouble(json['reward'] ?? json['rewardAmount']),
      type: taskType,
      schedule: json['schedule']?.toString() ?? json['timeSlot']?.toString(),
      rewardStatus: rs,
    );
  }

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

  // UC41 — tasks mà member báo không thể thực hiện
  List<TaskItem> get unavailableTasks =>
      _tasks.where((t) => t.status == 'UNAVAILABLE').toList();

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

  // UC44 — Manager duyệt / từ chối task đã nộp
  Future<void> approveTask(String id, {required bool approved}) async {
    final status = approved ? 'DONE' : 'REJECTED';
    await ApiClient.instance.patch('/tasks/$id', {'status': status});
    await fetchTasks();
  }

  // UC38 / UC39 — Manager tạo task (ad-hoc hoặc recurring)
  Future<void> createTask({
    required String title,
    String assigneeId = '',
    double reward = 0,
    TaskType type = TaskType.adHoc,
    String? schedule, // chỉ cho recurring: VD "07:00–07:30"
  }) async {
    await ApiClient.instance.post('/tasks', {
      'title': title,
      'type': type == TaskType.recurring ? 'RECURRING' : 'AD_HOC',
      if (assigneeId.isNotEmpty) 'assigneeId': assigneeId,
      if (reward > 0) 'reward': reward,
      if (schedule != null && schedule.isNotEmpty) 'schedule': schedule,
    });
    await fetchTasks();
  }

  // UC41 — Family Member báo không thể thực hiện task định kỳ
  Future<void> reportUnavailable(String taskId, String reason) async {
    await ApiClient.instance.patch('/tasks/$taskId', {
      'status': 'UNAVAILABLE',
      'unavailableReason': reason,
    });
    await fetchTasks();
  }

  // UC42 — Manager reassign task định kỳ sang member khác
  Future<void> reassignTask(String taskId, String newAssigneeId) async {
    await ApiClient.instance.patch('/tasks/$taskId', {
      'assigneeId': newAssigneeId,
      'status': 'TODO',
    });
    await fetchTasks();
  }

  // UC46 — Manager xác nhận đã thanh toán thưởng ngoài hệ thống
  Future<void> markRewardSettled(String taskId) async {
    await ApiClient.instance.patch('/tasks/$taskId', {'rewardStatus': 'SETTLED'});
    await fetchTasks();
  }

  // UC47 — Member xác nhận đã nhận thưởng
  Future<void> confirmRewardReceived(String taskId) async {
    await ApiClient.instance.patch('/tasks/$taskId', {'rewardStatus': 'CONFIRMED'});
    await fetchTasks();
  }

  // UC48 — Member báo chưa nhận được thưởng
  Future<void> disputeReward(String taskId) async {
    await ApiClient.instance.patch('/tasks/$taskId', {'rewardStatus': 'DISPUTED'});
    await fetchTasks();
  }

  // Các task DONE có reward > 0 chưa được settle (manager cần xử lý)
  List<TaskItem> get pendingRewardTasks => _tasks
      .where((t) =>
          t.status == 'DONE' &&
          t.reward > 0 &&
          (t.rewardStatus == RewardStatus.pending || t.rewardStatus == RewardStatus.disputed))
      .toList();
}
