import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String createdAt;
  final String? referenceId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.referenceId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']);
    final metadata = _asMap(json['metadata']);
    final payload = _asMap(json['payload']);
    final target = _asMap(json['target']);
    final sosAlert = _asMap(data['sosAlert'] ?? metadata['sosAlert'] ?? payload['sosAlert']);
    final task = _asMap(data['task'] ?? metadata['task'] ?? payload['task']);
    final assignment = _asMap(data['assignment'] ?? metadata['assignment'] ?? payload['assignment']);
    final submission = _asMap(data['submission'] ?? metadata['submission'] ?? payload['submission']);

    final type = _pickString([
          json['type'],
          json['notificationType'],
          json['eventType'],
          json['category'],
          json['entityType'],
          data['type'],
          data['notificationType'],
          data['eventType'],
          data['category'],
          data['entityType'],
          metadata['type'],
          metadata['eventType'],
          payload['type'],
          payload['eventType'],
          target['type'],
        ]) ??
        '';

    final referenceId = _pickString([
      data['alertId'],
      data['sosAlertId'],
      data['taskId'],
      data['assignmentId'],
      data['submissionId'],
      data['referenceId'],
      data['targetId'],
      data['entityId'],
      data['sourceId'],
      metadata['alertId'],
      metadata['sosAlertId'],
      metadata['taskId'],
      metadata['assignmentId'],
      metadata['submissionId'],
      metadata['referenceId'],
      metadata['targetId'],
      metadata['entityId'],
      payload['alertId'],
      payload['sosAlertId'],
      payload['taskId'],
      payload['assignmentId'],
      payload['submissionId'],
      payload['referenceId'],
      payload['targetId'],
      target['id'],
      sosAlert['id'],
      task['id'],
      assignment['id'],
      submission['id'],
      json['alertId'],
      json['sosAlertId'],
      json['taskId'],
      json['assignmentId'],
      json['submissionId'],
      json['referenceId'],
      json['targetId'],
      json['entityId'],
    ]);

    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? data['title']?.toString() ?? 'Thông báo',
      body: json['body']?.toString() ??
          json['message']?.toString() ??
          data['body']?.toString() ??
          data['message']?.toString() ??
          '',
      type: type,
      isRead: _parseBool(json['isRead'] ?? json['read'] ?? json['readAt']),
      createdAt: json['createdAt']?.toString() ??
          json['sentAt']?.toString() ??
          json['created_at']?.toString() ??
          '',
      referenceId: referenceId,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String? _pickString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return false;
    final text = value.toString().trim().toLowerCase();
    if (text == 'false' || text == '0') return false;
    return text == 'true' || text == '1' || text.isNotEmpty;
  }

  String get _upperType => type.toUpperCase();
  String get _searchText => '$type $title $body'.toLowerCase();

  bool get isSos => _upperType.contains('SOS');

  bool get isTask =>
      _upperType.contains('TASK') ||
      _upperType.contains('ASSIGNMENT') ||
      _upperType.contains('SUBMISSION') ||
      _searchText.contains('task') ||
      _searchText.contains('assignment') ||
      _searchText.contains('submission') ||
      _searchText.contains('nhiệm vụ') ||
      _searchText.contains('nhiệm vụ');

  bool get isFinance =>
      _upperType.contains('FINANCE') ||
      _upperType.contains('MONEY') ||
      _upperType.contains('BUDGET') ||
      _upperType.contains('LEDGER');

  String get emoji {
    if (isTask) return '\u{1F3C6}';
    if (isFinance) return '\u{1F4B0}';
    if (isSos) return '\u{1F6A8}';
    if (_upperType.contains('CALENDAR')) return '\u{1F4C5}';
    if (_upperType.contains('FAMILY')) return '\u{1F46A}';
    return '\u{1F514}';
  }

  Color get bgColor {
    if (isTask) return const Color(0xFFDCFCE7);
    if (isFinance) return const Color(0xFFFEF3C7);
    if (isSos) return const Color(0xFFFEE2E2);
    if (_upperType.contains('CALENDAR')) return const Color(0xFFEFF6FF);
    return const Color(0xFFF9FAFB);
  }
}

class NotificationProvider extends ChangeNotifier {
  String? _familyId;
  List<AppNotification> _notifications = [];
  bool _loading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _loading;
  String? get error => _error;

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchNotifications();
    }
  }

  Future<void> fetchNotifications() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$_familyId/notifications');
      final list = _extractList(data);
      _notifications = list
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_familyId == null) return;
    try {
      await ApiClient.instance.patch(
        '/families/$_familyId/notifications/$notificationId/read',
      );
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx >= 0) {
        _notifications[idx] = AppNotification(
          id: _notifications[idx].id,
          title: _notifications[idx].title,
          body: _notifications[idx].body,
          type: _notifications[idx].type,
          isRead: true,
          createdAt: _notifications[idx].createdAt,
          referenceId: _notifications[idx].referenceId,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    if (_familyId == null) return;
    try {
      await ApiClient.instance.patch('/families/$_familyId/notifications/read-all');
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                title: n.title,
                body: n.body,
                type: n.type,
                isRead: true,
                createdAt: n.createdAt,
                referenceId: n.referenceId,
              ))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is! Map) return const <dynamic>[];
    for (final key in const [
      'items',
      'data',
      'notifications',
      'results',
      'rows',
      'records',
    ]) {
      final value = data[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _extractList(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const <dynamic>[];
  }
}
