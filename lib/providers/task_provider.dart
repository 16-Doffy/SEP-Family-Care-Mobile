import 'package:flutter/material.dart';
import '../services/api_client.dart';

class TaskCategory {
  final String id;
  final String name;
  final String description;
  final String status;

  const TaskCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.status = 'ACTIVE',
  });

  factory TaskCategory.fromJson(Map<String, dynamic> j) => TaskCategory(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        status: j['status']?.toString() ?? 'ACTIVE',
      );
}

class TaskItem {
  final String id;
  final String assignmentId;
  final String title;
  final String description;
  final String status;
  final String assigneeName;
  final String assigneeId;
  final double reward;
  final bool isRecurring;
  final String? categoryName;
  final String? categoryId;
  final String? dueDate;
  final String? startAt;
  final String? note;

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
    this.categoryId,
    this.dueDate,
    this.startAt,
    this.note,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final task = json['task'] is Map
        ? Map<String, dynamic>.from(json['task'] as Map)
        : json;
    final isAssignment = json['task'] is Map;

    final assignee = task['assignee'] is Map ? task['assignee'] as Map : {};
    final rewardSetting =
        task['rewardSetting'] is Map ? task['rewardSetting'] as Map : {};
    final category =
        task['category'] is Map ? task['category'] as Map : {};

    return TaskItem(
      id: task['id']?.toString() ?? '',
      assignmentId: isAssignment ? json['id']?.toString() ?? '' : '',
      title: task['title']?.toString() ?? task['name']?.toString() ?? '',
      description: task['description']?.toString() ?? '',
      status:
          (isAssignment ? json['status'] : task['status'])?.toString() ?? 'TODO',
      assigneeName: assignee['displayName']?.toString() ?? '',
      assigneeId:
          task['assigneeId']?.toString() ?? assignee['id']?.toString() ?? '',
      reward: _parseDouble(
          rewardSetting['rewardAmount'] ?? task['reward'] ?? task['rewardAmount']),
      isRecurring: task['isRecurring'] as bool? ?? false,
      categoryName:
          category['name']?.toString() ?? task['categoryName']?.toString(),
      categoryId:
          category['id']?.toString() ?? task['categoryId']?.toString(),
      dueDate: (isAssignment ? json['dueAt'] : task['dueDate'])?.toString() ??
          task['dueDate']?.toString(),
      startAt: (isAssignment ? json['startAt'] : null)?.toString(),
      note: json['note']?.toString() ?? task['note']?.toString(),
    );
  }

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class RewardSettlement {
  final String id;
  final String taskTitle;
  final double amount;
  final String status;
  final String memberId;
  final String memberName;
  final String createdAt;

  const RewardSettlement({
    required this.id,
    required this.taskTitle,
    required this.amount,
    required this.status,
    required this.memberId,
    this.memberName = '',
    this.createdAt = '',
  });

  factory RewardSettlement.fromJson(Map<String, dynamic> j) {
    final task = j['task'] is Map ? j['task'] as Map : {};
    final member = j['member'] is Map ? j['member'] as Map : {};
    return RewardSettlement(
      id: j['id']?.toString() ?? '',
      taskTitle: task['title']?.toString() ?? j['taskTitle']?.toString() ?? '',
      amount: TaskItem._parseDouble(j['amount'] ?? j['rewardAmount']),
      status: j['status']?.toString() ?? 'PENDING',
      memberId: j['memberId']?.toString() ?? member['id']?.toString() ?? '',
      memberName:
          member['displayName']?.toString() ?? j['memberName']?.toString() ?? '',
      createdAt: j['createdAt']?.toString() ?? '',
    );
  }
}

class RewardDispute {
  final String id;
  final String settlementId;
  final String reason;
  final String status;
  final String reporterName;
  final String createdAt;

  const RewardDispute({
    required this.id,
    required this.settlementId,
    required this.reason,
    required this.status,
    this.reporterName = '',
    this.createdAt = '',
  });

  factory RewardDispute.fromJson(Map<String, dynamic> j) {
    final reporter = j['reporter'] is Map ? j['reporter'] as Map : {};
    return RewardDispute(
      id: j['id']?.toString() ?? '',
      settlementId:
          j['settlementId']?.toString() ?? j['rewardSettlementId']?.toString() ?? '',
      reason: j['reason']?.toString() ?? '',
      status: j['status']?.toString() ?? 'OPEN',
      reporterName:
          reporter['displayName']?.toString() ?? j['reporterName']?.toString() ?? '',
      createdAt: j['createdAt']?.toString() ?? '',
    );
  }
}

class TaskUnavailability {
  final String id;
  final String assignmentId;
  final String taskTitle;
  final String reason;
  final String status;
  final String memberName;
  final String createdAt;

  const TaskUnavailability({
    required this.id,
    required this.assignmentId,
    required this.taskTitle,
    required this.reason,
    required this.status,
    this.memberName = '',
    this.createdAt = '',
  });

  factory TaskUnavailability.fromJson(Map<String, dynamic> j) {
    final assignment = j['assignment'] is Map ? j['assignment'] as Map : {};
    final task = assignment['task'] is Map ? assignment['task'] as Map : {};
    final member = j['member'] is Map ? j['member'] as Map : {};
    return TaskUnavailability(
      id: j['id']?.toString() ?? '',
      assignmentId:
          j['assignmentId']?.toString() ?? assignment['id']?.toString() ?? '',
      taskTitle:
          task['title']?.toString() ?? j['taskTitle']?.toString() ?? '',
      reason: j['reason']?.toString() ?? '',
      status: j['status']?.toString() ?? 'PENDING',
      memberName:
          member['displayName']?.toString() ?? j['memberName']?.toString() ?? '',
      createdAt: j['createdAt']?.toString() ?? '',
    );
  }
}

class TaskProvider extends ChangeNotifier {
  String? _familyId;
  List<TaskItem> _tasks = [];
  List<TaskCategory> _categories = [];
  List<RewardSettlement> _settlements = [];
  List<RewardDispute> _disputes = [];
  List<TaskUnavailability> _unavailabilities = [];
  bool _loading = false;
  String? _error;

  List<TaskItem> get tasks => _tasks;
  List<TaskCategory> get categories => _categories;
  List<RewardSettlement> get settlements => _settlements;
  List<RewardDispute> get disputes => _disputes;
  List<TaskUnavailability> get unavailabilities => _unavailabilities;
  bool get isLoading => _loading;
  String? get error => _error;

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchTasks();
    }
  }

  // ─── Tasks ────────────────────────────────────────────────────────────────

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
      _tasks = _parseList(data)
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchTask(String taskId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    return Map<String, dynamic>.from(
      await ApiClient.instance.get('/families/$_familyId/tasks/$taskId') as Map,
    );
  }

  Future<void> createTask({
    required String title,
    String description = '',
    String? assigneeId,
    String? categoryId,
    double reward = 0,
    String? dueDate,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$_familyId/tasks', {
      'title': title,
      if (description.isNotEmpty) 'description': description,
      if (assigneeId != null && assigneeId.isNotEmpty)
        'assigneeId': assigneeId,
      if (categoryId != null && categoryId.isNotEmpty)
        'taskCategoryId': categoryId,
      if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
    });
    await fetchTasks();
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> body) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch('/families/$_familyId/tasks/$taskId', body);
    await fetchTasks();
  }

  Future<void> cancelTask(String taskId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch('/families/$_familyId/tasks/$taskId/cancel');
    await fetchTasks();
  }

  // ─── Categories ──────────────────────────────────────────────────────────

  Future<void> fetchCategories() async {
    if (_familyId == null) return;
    try {
      final data =
          await ApiClient.instance.get('/families/$_familyId/tasks/categories');
      _categories = _parseList(data)
          .map((e) => TaskCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> createCategory({
    required String name,
    String description = '',
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$_familyId/tasks/categories', {
      'name': name,
      if (description.isNotEmpty) 'description': description,
    });
    await fetchCategories();
  }

  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? status,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/categories/$categoryId',
      {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (status != null) 'status': status,
      },
    );
    await fetchCategories();
  }

  // ─── Assignments ─────────────────────────────────────────────────────────

  Future<void> fetchMyAssignments() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance
          .get('/families/$_familyId/tasks/my-assignments');
      _tasks = _parseList(data)
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchTaskAssignments(String taskId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance
        .get('/families/$_familyId/tasks/$taskId/assignments');
    return _parseList(data)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> fetchAssignment(String assignmentId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    return Map<String, dynamic>.from(
      await ApiClient.instance.get(
            '/families/$_familyId/tasks/assignments/$assignmentId',
          ) as Map,
    );
  }

  Future<void> assignTask(
    String taskId,
    String memberId, {
    String? startAt,
    String? dueAt,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/$taskId/assignments',
      {
        'assignedToMemberId': memberId,
        if (startAt != null) 'startAt': startAt,
        if (dueAt != null) 'dueAt': dueAt,
      },
    );
    await fetchTasks();
  }

  Future<void> startAssignment(String assignmentId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/assignments/$assignmentId/start',
    );
    await fetchMyAssignments();
  }

  Future<void> cancelAssignment(String assignmentId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/assignments/$assignmentId/cancel',
    );
    await fetchTasks();
  }

  Future<void> reassignTask(
    String assignmentId, {
    required String newMemberId,
    String? startAt,
    String? dueAt,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/assignments/$assignmentId/reassign',
      {
        'assignedToMemberId': newMemberId,
        if (startAt != null) 'startAt': startAt,
        if (dueAt != null) 'dueAt': dueAt,
      },
    );
    await fetchTasks();
  }

  // ─── Submissions ─────────────────────────────────────────────────────────

  Future<void> submitCompletion(String assignmentId, {String? note}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/assignments/$assignmentId/submissions',
      {if (note != null && note.isNotEmpty) 'note': note},
    );
  }

  Future<List<Map<String, dynamic>>> fetchSubmissions(
      String assignmentId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance.get(
      '/families/$_familyId/tasks/assignments/$assignmentId/submissions',
    );
    return _parseList(data).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> fetchSubmission(String submissionId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    return Map<String, dynamic>.from(
      await ApiClient.instance.get(
            '/families/$_familyId/tasks/submissions/$submissionId',
          ) as Map,
    );
  }

  Future<void> reviewSubmission(
    String submissionId, {
    required bool approved,
    String? note,
  }) async {
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

  // ─── Reward Settings ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchRewardSetting(String taskId) async {
    if (_familyId == null) return null;
    try {
      final data = await ApiClient.instance
          .get('/families/$_familyId/tasks/$taskId/reward-setting');
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> createRewardSetting(
    String taskId, {
    required String rewardType,
    required double rewardAmount,
    String rewardDescription = '',
    bool autoCreateSettlement = true,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/$taskId/reward-setting',
      {
        'rewardType': rewardType,
        'rewardAmount': rewardAmount,
        if (rewardDescription.isNotEmpty) 'rewardDescription': rewardDescription,
        'autoCreateSettlement': autoCreateSettlement,
      },
    );
  }

  Future<void> updateRewardSetting(
    String taskId, {
    String? rewardType,
    double? rewardAmount,
    String? rewardDescription,
    bool? autoCreateSettlement,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/$taskId/reward-setting',
      {
        if (rewardType != null) 'rewardType': rewardType,
        if (rewardAmount != null) 'rewardAmount': rewardAmount,
        if (rewardDescription != null) 'rewardDescription': rewardDescription,
        if (autoCreateSettlement != null)
          'autoCreateSettlement': autoCreateSettlement,
      },
    );
  }

  Future<void> deleteRewardSetting(String taskId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.delete(
      '/families/$_familyId/tasks/$taskId/reward-setting',
    );
  }

  // ─── Reward Settlements ───────────────────────────────────────────────────

  Future<void> fetchSettlements() async {
    if (_familyId == null) return;
    try {
      final data = await ApiClient.instance
          .get('/families/$_familyId/tasks/reward-settlements');
      _settlements = _parseList(data)
          .map((e) => RewardSettlement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> createSettlement(String submissionId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/submissions/$submissionId/reward-settlement',
      {},
    );
    await fetchSettlements();
  }

  Future<void> markSettlementPaid(String settlementId,
      {String? note}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/reward-settlements/$settlementId/mark-paid',
      {if (note != null && note.isNotEmpty) 'note': note},
    );
    await fetchSettlements();
  }

  Future<void> confirmSettlementReceived(String settlementId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/reward-settlements/$settlementId/confirm-received',
    );
    await fetchSettlements();
  }

  Future<void> cancelSettlement(String settlementId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/reward-settlements/$settlementId/cancel',
    );
    await fetchSettlements();
  }

  // ─── Reward Disputes ──────────────────────────────────────────────────────

  Future<void> fetchDisputes() async {
    if (_familyId == null) return;
    try {
      final data = await ApiClient.instance
          .get('/families/$_familyId/tasks/reward-disputes');
      _disputes = _parseList(data)
          .map((e) => RewardDispute.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> createDispute(String settlementId,
      {required String reason}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/reward-settlements/$settlementId/disputes',
      {'reason': reason},
    );
    await fetchDisputes();
  }

  Future<void> resolveDispute(String disputeId,
      {required String action, String? note}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/reward-disputes/$disputeId/resolve',
      {
        'action': action,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    await fetchDisputes();
    await fetchSettlements();
  }

  // ─── Recurring Tasks ──────────────────────────────────────────────────────

  Future<void> createRecurringTask({
    required String title,
    String description = '',
    String? categoryId,
    String priority = 'NORMAL',
    required Map<String, dynamic> schedule,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$_familyId/tasks/recurring', {
      'title': title,
      if (description.isNotEmpty) 'description': description,
      if (categoryId != null && categoryId.isNotEmpty)
        'taskCategoryId': categoryId,
      'priority': priority,
      'schedule': schedule,
    });
    await fetchTasks();
  }

  Future<Map<String, dynamic>?> fetchTaskSchedule(String taskId) async {
    if (_familyId == null) return null;
    try {
      final data = await ApiClient.instance
          .get('/families/$_familyId/tasks/$taskId/schedule');
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateTaskSchedule(
      String taskId, Map<String, dynamic> body) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance
        .patch('/families/$_familyId/tasks/$taskId/schedule', body);
  }

  Future<void> generateAssignments(String taskId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/$taskId/schedule/generate-assignments',
      {},
    );
    await fetchTasks();
  }

  // ─── Unavailability ───────────────────────────────────────────────────────

  Future<void> fetchUnavailabilities() async {
    if (_familyId == null) return;
    try {
      final data = await ApiClient.instance
          .get('/families/$_familyId/tasks/unavailabilities');
      _unavailabilities = _parseList(data)
          .map((e) =>
              TaskUnavailability.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> reportUnavailability(
    String assignmentId, {
    required String reason,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/tasks/assignments/$assignmentId/unavailability',
      {'reason': reason},
    );
    await fetchMyAssignments();
  }

  Future<void> cancelUnavailability(String unavailabilityId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/unavailabilities/$unavailabilityId/cancel',
    );
    await fetchUnavailabilities();
  }

  Future<void> handleUnavailability(
    String unavailabilityId, {
    required String action,
    String? newMemberId,
    String? startAt,
    String? dueAt,
    String? note,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/tasks/unavailabilities/$unavailabilityId/handle',
      {
        'action': action,
        if (newMemberId != null && newMemberId.isNotEmpty)
          'newAssignedToMemberId': newMemberId,
        if (startAt != null) 'startAt': startAt,
        if (dueAt != null) 'dueAt': dueAt,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    await fetchUnavailabilities();
    await fetchTasks();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  // Shortcut: duyệt task (legacy — dùng reviewSubmission cho submission flow)
  Future<void> approveTask(String taskId, {required bool approved}) async {
    await updateTask(taskId, {'status': approved ? 'DONE' : 'REJECTED'});
  }

  List<Map> _parseList(dynamic data) {
    if (data is List) return data.whereType<Map>().toList();
    if (data is Map && data['items'] is List) {
      return (data['items'] as List).whereType<Map>().toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().toList();
    }
    return [];
  }
}
