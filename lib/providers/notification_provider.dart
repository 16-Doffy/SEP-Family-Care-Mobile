import 'package:flutter/material.dart';
import '../services/api_client.dart';

// Field id thật là `notificationId`, KHÔNG phải `id` (đã verify trực tiếp
// trên BE — tạo SOS alert thật rồi đọc GET .../notifications, 2026-06-26).
class AppNotification {
  final String id;
  final String
  type; // SOS | TASK | FINANCE | INVITATION | ... (mở rộng theo BE)
  final String priority; // CRITICAL | HIGH | MEDIUM | LOW
  final String title;
  final String body;
  final String?
  referenceType; // SOS_ALERT | TASK_ASSIGNMENT | ... — dùng để tap-routing
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    this.referenceType,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['notificationId']?.toString() ?? json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        priority: json['priority']?.toString() ?? 'MEDIUM',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? json['message']?.toString() ?? '',
        referenceType: json['referenceType']?.toString(),
        referenceId: json['referenceId']?.toString(),
        isRead: json['isRead'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  String get emoji => switch (type) {
    'SOS' => '🚨',
    'TASK' => '✅',
    'FINANCE' => '💰',
    'INVITATION' => '✉️',
    'MEMBER_LEFT' => '🚪',
    _ => '🔔',
  };

  Color get accentColor => switch (priority) {
    'CRITICAL' => const Color(0xFFDC2626),
    'HIGH' => const Color(0xFFEA580C),
    'MEDIUM' => const Color(0xFF2563EB),
    _ => const Color(0xFF6B7280),
  };
}

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _loading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications({bool unreadOnly = false}) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final query = unreadOnly ? '?unreadOnly=true' : '';
      final data = await ApiClient.instance.get(
        '/families/$fid/notifications$query',
      );
      final list = data is List ? data : <dynamic>[];
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

  Future<void> markRead(String notificationId) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    try {
      await ApiClient.instance.patch(
        '/families/$fid/notifications/$notificationId/read',
        {},
      );
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        final old = _notifications[idx];
        _notifications[idx] = AppNotification(
          id: old.id,
          type: old.type,
          priority: old.priority,
          title: old.title,
          body: old.body,
          referenceType: old.referenceType,
          referenceId: old.referenceId,
          isRead: true,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    try {
      await ApiClient.instance.patch(
        '/families/$fid/notifications/read-all',
        {},
      );
      await fetchNotifications();
    } catch (_) {}
  }
}
