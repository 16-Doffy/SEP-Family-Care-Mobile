import 'package:flutter/material.dart';
import '../services/api_client.dart';

// ════════════════════════════════════════════════════════════════════════
// Models — khớp với BE Task API (35 endpoints):
//   Task ─┬─ TaskCategory
//         ├─ RewardSetting
//         ├─ TaskSchedule (RECURRING)
//         └─ TaskAssignment ─┬─ TaskUnavailability
//                            └─ TaskSubmission ─┬─ TaskProof[]
//                                               └─ RewardSettlement ── RewardDispute
// ════════════════════════════════════════════════════════════════════════

String? _str(dynamic v) => v?.toString();
double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class TaskCategory {
  final String id;
  final String name;
  final String? description;
  const TaskCategory({required this.id, required this.name, this.description});

  factory TaskCategory.fromJson(Map<String, dynamic> j) => TaskCategory(
        id: _str(j['id']) ?? '',
        name: _str(j['name']) ?? '',
        description: _str(j['description']),
      );
}

class RewardSetting {
  final String rewardType; // MONEY_RECORD | POINT | OTHER
  final double rewardAmount;
  final String? rewardDescription;
  final bool autoCreateSettlement;
  const RewardSetting({
    required this.rewardType,
    required this.rewardAmount,
    this.rewardDescription,
    this.autoCreateSettlement = false,
  });

  factory RewardSetting.fromJson(Map<String, dynamic> j) => RewardSetting(
        rewardType: _str(j['rewardType']) ?? 'MONEY_RECORD',
        rewardAmount: _num(j['rewardAmount']),
        rewardDescription: _str(j['rewardDescription']),
        autoCreateSettlement: j['autoCreateSettlement'] == true,
      );

  String get label => switch (rewardType) {
        'POINT' => '${rewardAmount.toStringAsFixed(0)} điểm',
        'OTHER' => rewardDescription ?? 'Phần thưởng khác',
        _       => '${rewardAmount.toStringAsFixed(0)} ₫',
      };
}

class TaskSchedule {
  final String? id;
  final String repeatType; // DAILY | WEEKLY | MONTHLY
  final int repeatInterval;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? dayOfWeek;
  final String status; // ACTIVE | INACTIVE
  const TaskSchedule({
    this.id,
    required this.repeatType,
    required this.repeatInterval,
    this.startDate,
    this.endDate,
    this.dayOfWeek,
    this.status = 'ACTIVE',
  });

  factory TaskSchedule.fromJson(Map<String, dynamic> j) => TaskSchedule(
        id: _str(j['id']),
        repeatType: _str(j['repeatType']) ?? 'DAILY',
        repeatInterval: (j['repeatInterval'] as num?)?.toInt() ?? 1,
        startDate: _date(j['startDate']),
        endDate: _date(j['endDate']),
        dayOfWeek: (j['dayOfWeek'] as num?)?.toInt(),
        status: _str(j['status']) ?? 'ACTIVE',
      );

  String get label => switch (repeatType) {
        'DAILY'   => 'Hàng ngày (mỗi $repeatInterval ngày)',
        'WEEKLY'  => 'Hàng tuần (mỗi $repeatInterval tuần)',
        'MONTHLY' => 'Hàng tháng (mỗi $repeatInterval tháng)',
        _         => repeatType,
      };
}

class FamilyTask {
  final String id;
  final String title;
  final String? description;
  final String? taskCategoryId;
  final String? taskCategoryName;
  final String taskType; // AD_HOC | RECURRING
  final String priority; // LOW | MEDIUM | HIGH
  final String status;   // DRAFT | ACTIVE | COMPLETED | CANCELED
  final DateTime? dueAt;
  final RewardSetting? rewardSetting;
  final TaskSchedule? schedule;

  const FamilyTask({
    required this.id,
    required this.title,
    this.description,
    this.taskCategoryId,
    this.taskCategoryName,
    this.taskType = 'AD_HOC',
    this.priority = 'MEDIUM',
    this.status = 'ACTIVE',
    this.dueAt,
    this.rewardSetting,
    this.schedule,
  });

  bool get isRecurring => taskType == 'RECURRING';

  factory FamilyTask.fromJson(Map<String, dynamic> j) {
    final cat = j['taskCategory'] is Map ? j['taskCategory'] as Map : <String, dynamic>{};
    return FamilyTask(
      id: _str(j['id']) ?? '',
      title: _str(j['title']) ?? '',
      description: _str(j['description']),
      taskCategoryId: _str(j['taskCategoryId']) ?? _str(cat['id']),
      taskCategoryName: _str(cat['name']),
      taskType: _str(j['taskType']) ?? 'AD_HOC',
      priority: _str(j['priority']) ?? 'MEDIUM',
      status: _str(j['status']) ?? 'ACTIVE',
      dueAt: _date(j['dueAt']),
      rewardSetting: j['rewardSetting'] is Map
          ? RewardSetting.fromJson(Map<String, dynamic>.from(j['rewardSetting']))
          : null,
      schedule: j['schedule'] is Map
          ? TaskSchedule.fromJson(Map<String, dynamic>.from(j['schedule']))
          : null,
    );
  }
}

class TaskAssignment {
  final String id;
  final String taskId;
  final String? taskTitle;
  final String assignedToMemberId;
  final String? assignedToName;
  final DateTime? startAt;
  final DateTime? dueAt;
  final String status; // PENDING|IN_PROGRESS|SUBMITTED|APPROVED|REJECTED|CANCELED|UNAVAILABLE
  final RewardSetting? rewardSetting;
  final FamilyTask? task;
  final String? latestSubmissionId; // cần để gọi review — lấy từ embedded submission nếu BE trả về

  const TaskAssignment({
    required this.id,
    required this.taskId,
    this.taskTitle,
    required this.assignedToMemberId,
    this.assignedToName,
    this.startAt,
    this.dueAt,
    this.status = 'PENDING',
    this.rewardSetting,
    this.task,
    this.latestSubmissionId,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> j) {
    final taskMap = j['task'] is Map ? Map<String, dynamic>.from(j['task']) : null;
    final member = j['assignedToMember'] is Map
        ? j['assignedToMember'] as Map
        : (j['member'] is Map ? j['member'] as Map : <String, dynamic>{});
    final userMap = member['user'] is Map ? member['user'] as Map : <String, dynamic>{};
    // Submission có thể embedded dạng object đơn hoặc list (lấy cái mới nhất)
    String? submissionId;
    if (j['submission'] is Map) {
      submissionId = _str((j['submission'] as Map)['id']);
    } else if (j['latestSubmission'] is Map) {
      submissionId = _str((j['latestSubmission'] as Map)['id']);
    } else if (j['submissions'] is List && (j['submissions'] as List).isNotEmpty) {
      final last = (j['submissions'] as List).last;
      if (last is Map) submissionId = _str(last['id']);
    }
    return TaskAssignment(
      id: _str(j['id']) ?? '',
      taskId: _str(j['taskId']) ?? _str(taskMap?['id']) ?? '',
      taskTitle: _str(taskMap?['title']) ?? _str(j['taskTitle']),
      assignedToMemberId: _str(j['assignedToMemberId']) ?? _str(member['id']) ?? '',
      assignedToName: _str(userMap['fullName']) ?? _str(member['displayName']) ?? _str(j['assignedToName']),
      startAt: _date(j['startAt']),
      dueAt: _date(j['dueAt']),
      status: _str(j['status']) ?? 'PENDING',
      rewardSetting: j['rewardSetting'] is Map
          ? RewardSetting.fromJson(Map<String, dynamic>.from(j['rewardSetting']))
          : null,
      task: taskMap != null ? FamilyTask.fromJson(taskMap) : null,
      latestSubmissionId: submissionId,
    );
  }

  Color get statusColor => switch (status) {
        'IN_PROGRESS' => const Color(0xFFD97706),
        'SUBMITTED'   => const Color(0xFF2563EB),
        'APPROVED'    => const Color(0xFF16A34A),
        'REJECTED'    => const Color(0xFFDC2626),
        'CANCELED'    => const Color(0xFF6B7280),
        'UNAVAILABLE' => const Color(0xFFEA580C),
        _             => const Color(0xFF6B7280),
      };

  String get statusLabel => switch (status) {
        'ASSIGNED'    => '⚪ Chờ làm',
        'IN_PROGRESS' => '🔵 Đang làm',
        'SUBMITTED'   => '⏳ Chờ duyệt',
        'APPROVED'    => '✅ Hoàn thành',
        'REJECTED'    => '❌ Từ chối',
        'CANCELED'    => '🚫 Đã hủy',
        'UNAVAILABLE' => '🙅 Báo bận',
        _             => '⚪ Chờ làm',
      };
}

class TaskProof {
  final String? id;
  final String proofType; // IMAGE | VIDEO | NOTE | FILE
  final String? fileUrl;
  final String? thumbnailUrl;
  final String? note;
  const TaskProof({this.id, required this.proofType, this.fileUrl, this.thumbnailUrl, this.note});

  factory TaskProof.fromJson(Map<String, dynamic> j) => TaskProof(
        id: _str(j['id']),
        proofType: _str(j['proofType']) ?? 'NOTE',
        fileUrl: _str(j['fileUrl']),
        thumbnailUrl: _str(j['thumbnailUrl']),
        note: _str(j['note']),
      );

  Map<String, dynamic> toJson() => {
        'proofType': proofType,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (note != null) 'note': note,
      };
}

class TaskSubmission {
  final String id;
  final String assignmentId;
  final String? submissionNote;
  final List<TaskProof> proofs;
  final String status; // PENDING | APPROVED | REJECTED
  final String? reviewNote;
  const TaskSubmission({
    required this.id,
    required this.assignmentId,
    this.submissionNote,
    this.proofs = const [],
    this.status = 'PENDING',
    this.reviewNote,
  });

  factory TaskSubmission.fromJson(Map<String, dynamic> j) => TaskSubmission(
        id: _str(j['id']) ?? '',
        assignmentId: _str(j['assignmentId']) ?? _str(j['taskAssignmentId']) ?? '',
        submissionNote: _str(j['submissionNote']),
        proofs: (j['proofs'] as List? ?? [])
            .whereType<Map>()
            .map((e) => TaskProof.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        status: _str(j['status']) ?? 'PENDING',
        reviewNote: _str(j['reviewNote']),
      );
}

class RewardSettlement {
  final String id;
  final String? submissionId;
  final String? memberName;
  final double amount;
  // Enum thật (verify Swagger 2026-07-08): PENDING_SETTLEMENT |
  // WAITING_CONFIRMATION | SETTLED | DISPUTED | CANCELED — trước đó model
  // dùng PENDING/AWAITING_PAYMENT/PAID/CONFIRMED sai hoàn toàn.
  final String status;
  final String? note;
  const RewardSettlement({
    required this.id,
    this.submissionId,
    this.memberName,
    this.amount = 0,
    this.status = 'PENDING_SETTLEMENT',
    this.note,
  });

  bool get needsMarkPaid => status == 'PENDING_SETTLEMENT';

  factory RewardSettlement.fromJson(Map<String, dynamic> j) {
    final member = j['member'] is Map ? j['member'] as Map : <String, dynamic>{};
    final userMap = member['user'] is Map ? member['user'] as Map : <String, dynamic>{};
    return RewardSettlement(
      id: _str(j['id']) ?? '',
      submissionId: _str(j['submissionId']) ?? _str(j['taskSubmissionId']),
      memberName: _str(userMap['fullName']) ?? _str(j['memberName']),
      amount: _num(j['amount'] ?? j['rewardAmount']),
      status: _str(j['status']) ?? 'PENDING_SETTLEMENT',
      note: _str(j['note']) ?? _str(j['resolutionNote']),
    );
  }

  Color get statusColor => switch (status) {
        'SETTLED'             => const Color(0xFF16A34A),
        'WAITING_CONFIRMATION' => const Color(0xFF2563EB),
        'DISPUTED'             => const Color(0xFFDC2626),
        'CANCELED'             => const Color(0xFF6B7280),
        _                      => const Color(0xFFD97706),
      };

  String get statusLabel => switch (status) {
        'SETTLED'              => '✅ Đã nhận',
        'WAITING_CONFIRMATION' => '💸 Đã trả, chờ xác nhận',
        'DISPUTED'             => '⚠️ Tranh chấp',
        'CANCELED'             => '🚫 Đã hủy',
        _                      => '⏳ Chờ thanh toán',
      };
}

class RewardDispute {
  final String id;
  final String settlementId;
  final String reason;
  final String status; // OPEN | RESOLVED | REJECTED (verify Swagger 2026-07-08)
  final String? resolutionNote;
  const RewardDispute({
    required this.id,
    required this.settlementId,
    required this.reason,
    this.status = 'OPEN',
    this.resolutionNote,
  });

  factory RewardDispute.fromJson(Map<String, dynamic> j) => RewardDispute(
        id: _str(j['id']) ?? '',
        settlementId: _str(j['settlementId']) ?? _str(j['rewardSettlementId']) ?? '',
        reason: _str(j['reason']) ?? '',
        status: _str(j['status']) ?? 'OPEN',
        resolutionNote: _str(j['resolutionNote']),
      );
}

class TaskUnavailability {
  final String id;
  final String assignmentId;
  final String reason;
  // Enum thật (verify Swagger 2026-07-08): REPORTED | HANDLED | CANCELED —
  // trước đó model giả định "OPEN" sai, khiến UI chờ xử lý không bao giờ khớp.
  final String status;
  const TaskUnavailability({
    required this.id,
    required this.assignmentId,
    required this.reason,
    this.status = 'REPORTED',
  });

  bool get isOpen => status == 'REPORTED';

  factory TaskUnavailability.fromJson(Map<String, dynamic> j) => TaskUnavailability(
        id: _str(j['id']) ?? '',
        assignmentId: _str(j['assignmentId']) ?? _str(j['taskAssignmentId']) ?? '',
        reason: _str(j['reason']) ?? '',
        status: _str(j['status']) ?? 'REPORTED',
      );
}

// ════════════════════════════════════════════════════════════════════════
// Provider
// ════════════════════════════════════════════════════════════════════════

class TaskProvider extends ChangeNotifier {
  List<FamilyTask> tasks = [];
  List<TaskCategory> categories = [];
  List<TaskAssignment> myAssignments = [];
  final Map<String, List<TaskAssignment>> _assignmentsByTask = {};
  List<RewardSettlement> rewardSettlements = [];
  List<RewardDispute> rewardDisputes = [];
  List<TaskUnavailability> unavailabilities = [];

  bool loading = false;
  String? error;

  List<TaskAssignment> assignmentsFor(String taskId) => _assignmentsByTask[taskId] ?? [];

  String get _fid {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    return fid;
  }

  String _qs(Map<String, dynamic> params) {
    final entries = params.entries.where((e) => e.value != null && e.value.toString().isNotEmpty);
    if (entries.isEmpty) return '';
    return '?${entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value.toString())}').join('&')}';
  }

  // ── Tasks ────────────────────────────────────────────────────────────────

  Future<void> fetchTasks({String? status, String? taskCategoryId, String? priority, String? taskType}) async {
    loading = true; error = null;
    tasks = [];
    notifyListeners();
    try {
      final qs = _qs({'status': status, 'taskCategoryId': taskCategoryId, 'priority': priority, 'taskType': taskType, 'limit': 100});
      final data = await ApiClient.instance.get('/families/$_fid/tasks$qs');
      tasks = _list(data).map(FamilyTask.fromJson).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<FamilyTask?> createTask({
    required String title,
    String? description,
    String? taskCategoryId,
    String taskType = 'AD_HOC',
    String priority = 'MEDIUM',
    String status = 'ACTIVE',
    DateTime? dueAt,
  }) async {
    final res = await ApiClient.instance.post('/families/$_fid/tasks', {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      if (taskCategoryId != null && taskCategoryId.isNotEmpty) 'taskCategoryId': taskCategoryId,
      'taskType': taskType,
      'priority': priority,
      'status': status,
      if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
    });
    await fetchTasks();
    return res.isNotEmpty ? FamilyTask.fromJson(res) : null;
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> patch) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/$taskId', patch);
    await fetchTasks();
  }

  Future<void> cancelTask(String taskId) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/$taskId/cancel', {});
    await fetchTasks();
  }

  // ── Recurring task + Schedule ──────────────────────────────────────────

  Future<FamilyTask?> createRecurringTask({
    required String title,
    String? description,
    String? taskCategoryId,
    String priority = 'MEDIUM',
    required String repeatType, // DAILY|WEEKLY|MONTHLY
    required int repeatInterval,
    required DateTime startDate,
    DateTime? endDate,
    int? dayOfWeek,
  }) async {
    final res = await ApiClient.instance.post('/families/$_fid/tasks/recurring', {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      if (taskCategoryId != null && taskCategoryId.isNotEmpty) 'taskCategoryId': taskCategoryId,
      'priority': priority,
      'status': 'ACTIVE',
      'schedule': {
        'repeatType': repeatType,
        'repeatInterval': repeatInterval,
        'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        'dayOfWeek': dayOfWeek,
        'status': 'ACTIVE',
      },
    });
    await fetchTasks();
    return res.isNotEmpty ? FamilyTask.fromJson(res) : null;
  }

  Future<void> updateSchedule(String taskId, Map<String, dynamic> patch) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/$taskId/schedule', patch);
    await fetchTasks();
  }

  Future<void> generateAssignments(String taskId, {
    required String assignedToMemberId,
    required DateTime fromDate,
    required DateTime toDate,
    String? startTime,
    String? dueTime,
  }) async {
    await ApiClient.instance.post('/families/$_fid/tasks/$taskId/schedule/generate-assignments', {
      'assignedToMemberId': assignedToMemberId,
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'startTime': ?startTime,
      'dueTime': ?dueTime,
    });
    await fetchTaskAssignments(taskId);
    await fetchMyAssignments();
  }

  // ── Categories ───────────────────────────────────────────────────────────

  Future<void> fetchCategories() async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/categories?limit=100');
      categories = _list(data).map(TaskCategory.fromJson).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('TaskProvider: fetchCategories failed: $e');
    }
  }

  Future<TaskCategory?> createCategory({required String name, String? description}) async {
    final res = await ApiClient.instance.post('/families/$_fid/tasks/categories', {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    await fetchCategories();
    return res.isNotEmpty ? TaskCategory.fromJson(res) : null;
  }

  // ── Assignments ──────────────────────────────────────────────────────────

  Future<void> assignTask(String taskId, {
    required String assignedToMemberId,
    DateTime? startAt,
    DateTime? dueAt,
  }) async {
    await ApiClient.instance.post('/families/$_fid/tasks/$taskId/assignments', {
      'assignedToMemberId': assignedToMemberId,
      if (startAt != null) 'startAt': startAt.toIso8601String(),
      if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
    });
    await fetchTaskAssignments(taskId);
  }

  Future<void> fetchTaskAssignments(String taskId, {String? status}) async {
    _assignmentsByTask[taskId] = [];
    notifyListeners();
    try {
      final qs = _qs({'status': status, 'limit': 100});
      final data = await ApiClient.instance.get('/families/$_fid/tasks/$taskId/assignments$qs');
      _assignmentsByTask[taskId] = _list(data).map(TaskAssignment.fromJson).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('TaskProvider: fetchTaskAssignments failed: $e');
    }
  }

  Future<void> fetchMyAssignments({
    String? status, String? priority, DateTime? startFrom, DateTime? startTo, DateTime? dueFrom, DateTime? dueTo,
  }) async {
    loading = true; error = null; notifyListeners();
    try {
      final qs = _qs({
        'status': status, 'priority': priority,
        'startFrom': startFrom?.toIso8601String(), 'startTo': startTo?.toIso8601String(),
        'dueFrom': dueFrom?.toIso8601String(), 'dueTo': dueTo?.toIso8601String(),
        'limit': 100,
      });
      final data = await ApiClient.instance.get('/families/$_fid/tasks/my-assignments$qs');
      myAssignments = _list(data).map(TaskAssignment.fromJson).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<TaskAssignment?> getAssignmentDetail(String assignmentId) async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/assignments/$assignmentId');
      return data is Map<String, dynamic> ? TaskAssignment.fromJson(data) : null;
    } catch (e) {
      debugPrint('TaskProvider: getAssignmentDetail failed: $e');
      return null;
    }
  }

  Future<void> startAssignment(String assignmentId) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/assignments/$assignmentId/start', {});
    await fetchMyAssignments();
  }

  Future<void> cancelAssignment(String assignmentId) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/assignments/$assignmentId/cancel', {});
    await fetchMyAssignments();
  }

  Future<void> reassignAssignment(String assignmentId, {
    required String assignedToMemberId, DateTime? startAt, DateTime? dueAt,
  }) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/assignments/$assignmentId/reassign', {
      'assignedToMemberId': assignedToMemberId,
      if (startAt != null) 'startAt': startAt.toIso8601String(),
      if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
    });
  }

  // ── Proof upload ─────────────────────────────────────────────────────────

  Future<TaskProof?> uploadProof(String filePath, String proofType) async {
    final res = await ApiClient.instance.uploadFile(
      path: '/families/$_fid/tasks/proofs/upload',
      filePath: filePath,
      queryParams: {'proofType': proofType},
    );
    return res.isNotEmpty ? TaskProof.fromJson(res) : null;
  }

  // ── Submissions ──────────────────────────────────────────────────────────

  Future<void> submitProof(String assignmentId, {String? submissionNote, required List<TaskProof> proofs}) async {
    await ApiClient.instance.post('/families/$_fid/tasks/assignments/$assignmentId/submissions', {
      if (submissionNote != null && submissionNote.isNotEmpty) 'submissionNote': submissionNote,
      'proofs': proofs.map((p) => p.toJson()).toList(),
    });
    await fetchMyAssignments();
  }

  Future<void> reviewSubmission(String submissionId, {required bool approved, String? reviewNote}) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/submissions/$submissionId/review', {
      'decision': approved ? 'APPROVED' : 'REJECTED',
      if (reviewNote != null && reviewNote.isNotEmpty) 'reviewNote': reviewNote,
    });
    await fetchTasks();
  }

  // GET .../assignments/{id}/submissions — BE không embed submission trong
  // response danh sách assignment (chỉ trả status), nên TaskAssignment.
  // latestSubmissionId luôn null dù status đã SUBMITTED. Phải gọi riêng
  // endpoint này trước khi duyệt.
  Future<TaskSubmission?> fetchLatestSubmission(String assignmentId) async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/assignments/$assignmentId/submissions');
      final list = _list(data).map((e) => TaskSubmission.fromJson(Map<String, dynamic>.from(e))).toList();
      if (list.isEmpty) return null;
      final latest = list.last;
      // List submissions chỉ trả proofCount, KHÔNG kèm mảng proofs (verified
      // live) — phải gọi thêm detail để manager thấy ảnh/ghi chú minh chứng.
      try {
        final detail = await ApiClient.instance.get('/families/$_fid/tasks/submissions/${latest.id}');
        if (detail is Map<String, dynamic>) {
          return TaskSubmission.fromJson(detail);
        }
      } catch (e) {
        debugPrint('TaskProvider: fetch submission detail failed: $e');
      }
      return latest;
    } catch (e) {
      debugPrint('TaskProvider: fetchLatestSubmission failed: $e');
      return null;
    }
  }

  // ── Reward setting ───────────────────────────────────────────────────────

  Future<void> setRewardSetting(String taskId, {
    required String rewardType, double? rewardAmount, String? rewardDescription, bool autoCreateSettlement = false,
  }) async {
    await ApiClient.instance.post('/families/$_fid/tasks/$taskId/reward-setting', {
      'rewardType': rewardType,
      'rewardAmount': ?rewardAmount,
      if (rewardDescription != null && rewardDescription.isNotEmpty) 'rewardDescription': rewardDescription,
      'autoCreateSettlement': autoCreateSettlement,
    });
    await fetchTasks();
  }

  // ── Reward settlement ────────────────────────────────────────────────────

  Future<void> createSettlement(String submissionId) async {
    await ApiClient.instance.post('/families/$_fid/tasks/submissions/$submissionId/reward-settlement', {});
    await fetchRewardSettlements();
  }

  Future<void> fetchRewardSettlements() async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/reward-settlements?limit=100');
      rewardSettlements = _list(data).map(RewardSettlement.fromJson).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('TaskProvider: fetchRewardSettlements failed: $e');
    }
  }

  // MarkRewardPaidDto thật: { externalMethod (bắt buộc, enum), externalNote? }
  // — verify Swagger 2026-07-08, KHÔNG phải { note } như trước.
  /// externalMethod: CASH | BANK_TRANSFER | THIRD_PARTY_WALLET | OTHER
  Future<void> markRewardPaid(String settlementId, {required String externalMethod, String? externalNote}) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/reward-settlements/$settlementId/mark-paid', {
      'externalMethod': externalMethod,
      'externalNote': ?externalNote,
    });
    await fetchRewardSettlements();
  }

  Future<void> confirmRewardReceived(String settlementId) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/reward-settlements/$settlementId/confirm-received', {});
    await fetchRewardSettlements();
  }

  Future<void> cancelSettlement(String settlementId) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/reward-settlements/$settlementId/cancel', {});
    await fetchRewardSettlements();
  }

  // Body key thật là `allocations` (đã verify Swagger CreateRewardAllocationDto
  // 2026-07-08) — trước đó gửi `items` sẽ bị BE trả 400.
  Future<void> createAllocation(String settlementId, List<Map<String, dynamic>> items) async {
    await ApiClient.instance.post('/families/$_fid/tasks/reward-settlements/$settlementId/allocations', {
      'allocations': items,
    });
  }

  // GET .../reward-settlements/{id} — chi tiết 1 settlement.
  Future<Map<String, dynamic>> fetchSettlementDetail(String settlementId) async {
    final data = await ApiClient.instance.get('/families/$_fid/tasks/reward-settlements/$settlementId');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // GET .../reward-settlements/{id}/allocations — breakdown phân bổ (nếu
  // reward được chia làm nhiều phần).
  Future<List<Map<String, dynamic>>> fetchSettlementAllocations(String settlementId) async {
    final data = await ApiClient.instance.get('/families/$_fid/tasks/reward-settlements/$settlementId/allocations');
    return _list(data);
  }

  // ── Reward disputes ──────────────────────────────────────────────────────

  Future<void> createDispute(String settlementId, String reason) async {
    await ApiClient.instance.post('/families/$_fid/tasks/reward-settlements/$settlementId/disputes', {
      'reason': reason,
    });
    await fetchRewardDisputes();
  }

  Future<void> fetchRewardDisputes() async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/reward-disputes?limit=100');
      rewardDisputes = _list(data).map(RewardDispute.fromJson).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('TaskProvider: fetchRewardDisputes failed: $e');
    }
  }

  // ResolveRewardDisputeDto thật: { action } — verify Swagger 2026-07-08,
  // KHÔNG phải { resolutionNote } như trước.
  /// action: ACCEPT_DISPUTE | REJECT_DISPUTE
  Future<void> resolveDispute(String disputeId, String action) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/reward-disputes/$disputeId/resolve', {
      'action': action,
    });
    await fetchRewardDisputes();
  }

  // GET .../reward-disputes/{id} — chi tiết 1 tranh chấp.
  Future<Map<String, dynamic>> fetchDisputeDetail(String disputeId) async {
    final data = await ApiClient.instance.get('/families/$_fid/tasks/reward-disputes/$disputeId');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ── Unavailability ───────────────────────────────────────────────────────

  Future<void> reportUnavailability(String assignmentId, String reason) async {
    await ApiClient.instance.post('/families/$_fid/tasks/assignments/$assignmentId/unavailability', {
      'reason': reason,
    });
    await fetchMyAssignments();
  }

  Future<void> fetchUnavailabilities() async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/unavailabilities?limit=100');
      unavailabilities = _list(data).map(TaskUnavailability.fromJson).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('TaskProvider: fetchUnavailabilities failed: $e');
    }
  }

  Future<void> cancelUnavailability(String id) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/unavailabilities/$id/cancel', {});
    await fetchUnavailabilities();
  }

  Future<void> handleUnavailability(String id, {
    required String action, // REASSIGN | CANCEL_ASSIGNMENT | MARK_HANDLED
    String? newAssignedToMemberId, DateTime? startAt, DateTime? dueAt, String? note,
  }) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/unavailabilities/$id/handle', {
      'action': action,
      'newAssignedToMemberId': ?newAssignedToMemberId,
      if (startAt != null) 'startAt': startAt.toIso8601String(),
      if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    await fetchUnavailabilities();
  }

  // GET .../unavailabilities/{id} — chi tiết 1 báo bận.
  Future<Map<String, dynamic>> fetchUnavailabilityDetail(String id) async {
    final data = await ApiClient.instance.get('/families/$_fid/tasks/unavailabilities/$id');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ── Task edit / category edit / reward-setting edit ─────────────────────

  // GET .../tasks/{taskId}/reward-setting — đọc riêng (FamilyTask.rewardSetting
  // đã embed sẵn từ fetchTasks, gọi thêm khi cần refresh mới nhất trước khi sửa).
  Future<RewardSetting?> fetchRewardSetting(String taskId) async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/$taskId/reward-setting');
      return data is Map<String, dynamic> && data.isNotEmpty ? RewardSetting.fromJson(data) : null;
    } catch (e) {
      debugPrint('TaskProvider: fetchRewardSetting failed: $e');
      return null;
    }
  }

  Future<void> updateRewardSetting(String taskId, {
    String? rewardType, double? rewardAmount, String? rewardDescription, bool? autoCreateSettlement,
  }) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/$taskId/reward-setting', {
      'rewardType': ?rewardType,
      'rewardAmount': ?rewardAmount,
      'rewardDescription': ?rewardDescription,
      'autoCreateSettlement': ?autoCreateSettlement,
    });
    await fetchTasks();
  }

  Future<void> deleteRewardSetting(String taskId) async {
    await ApiClient.instance.delete('/families/$_fid/tasks/$taskId/reward-setting');
    await fetchTasks();
  }

  Future<void> updateCategory(String categoryId, {String? name, String? description}) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/categories/$categoryId', {
      'name': ?name,
      'description': ?description,
    });
    await fetchCategories();
  }

  // GET .../tasks/submissions/{submissionId} — chi tiết 1 submission theo ID
  // trực tiếp (khác fetchLatestSubmission vốn GET theo assignment rồi lấy
  // phần tử cuối — dùng khi đã có sẵn submissionId, ví dụ từ settlement).
  Future<TaskSubmission?> fetchSubmissionDetail(String submissionId) async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/submissions/$submissionId');
      return data is Map<String, dynamic> ? TaskSubmission.fromJson(data) : null;
    } catch (e) {
      debugPrint('TaskProvider: fetchSubmissionDetail failed: $e');
      return null;
    }
  }

  Future<void> updateProof(String proofId, {String? note}) async {
    await ApiClient.instance.patch('/families/$_fid/tasks/proofs/$proofId', {
      'note': ?note,
    });
  }

  Future<void> deleteProof(String proofId) async {
    await ApiClient.instance.delete('/families/$_fid/tasks/proofs/$proofId');
  }

  // GET .../tasks/{taskId}/schedule — đọc riêng lịch lặp (FamilyTask.schedule
  // đã embed sẵn, gọi thêm khi cần refresh mới nhất trước khi sửa).
  Future<TaskSchedule?> fetchSchedule(String taskId) async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/tasks/$taskId/schedule');
      return data is Map<String, dynamic> && data.isNotEmpty ? TaskSchedule.fromJson(data) : null;
    } catch (e) {
      debugPrint('TaskProvider: fetchSchedule failed: $e');
      return null;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _list(dynamic data) {
    final raw = data is List
        ? data
        : data is Map && data['items'] is List
            ? data['items'] as List
            : data is Map && data['data'] is List
                ? data['data'] as List
                : <dynamic>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
