import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/notification_socket_service.dart';

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

  Color get accentColor => switch (priority) {
    'CRITICAL' => const Color(0xFFDC2626),
    'HIGH' => const Color(0xFFEA580C),
    'MEDIUM' || 'NORMAL' => const Color(0xFF2563EB),
    _ => const Color(0xFF6B7280),
  };
}

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _loading = false;
  String? _error;

  // Unread-count realtime theo từng family (event notification:unread-count).
  final Map<String, int> _familyUnread = {};
  bool _realtimeOn = false;

  // Toast/banner cho notification push-only (id null) — UI shell gắn vào.
  void Function(AppNotification n)? onTransient;

  List<AppNotification> get notifications => _notifications;
  bool get loading => _loading;
  String? get error => _error;

  // Ưu tiên count realtime của family đang active; fallback đếm từ list.
  int get unreadCount {
    final fid = ApiClient.instance.familyId;
    final rt = fid == null ? null : _familyUnread[fid];
    return rt ?? _notifications.where((n) => !n.isRead).length;
  }

  // ── Realtime (Socket.IO /notifications) ──────────────────────────────────
  void startRealtime() {
    if (_realtimeOn) return;
    _realtimeOn = true;
    final svc = NotificationSocketService.instance;
    svc.onNotification = _applyRealtime;
    svc.onUnreadCount = (fid, count) {
      if (fid != null) {
        _familyUnread[fid] = count;
        notifyListeners();
      }
    };
    svc.connect();
  }

  void stopRealtime() {
    _realtimeOn = false;
    final svc = NotificationSocketService.instance;
    svc.onNotification = null;
    svc.onUnreadCount = null;
    svc.disconnect();
    _familyUnread.clear();
  }

  void _applyRealtime(Map<String, dynamic> payload) {
    final n = AppNotification.fromJson(payload);
    // id null = push-only: chỉ toast tức thời, KHÔNG thêm list / KHÔNG tăng
    // badge (badge do event unread-count riêng đẩy). Xem hợp đồng WS.
    final pushOnly = payload['id'] == null;
    if (pushOnly) {
      onTransient?.call(n);
      return;
    }
    // Persisted: chèn lên đầu nếu chưa có, đồng thời toast nhẹ.
    if (_notifications.every((e) => e.id != n.id)) {
      _notifications = [n, ..._notifications];
      onTransient?.call(n);
      notifyListeners();
    }
  }

  // Badge lúc khởi động (trước khi socket bắn event đầu tiên).
  Future<void> fetchUnreadCount() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/notifications/unread-count',
      );
      final c = data is Map ? (data['count'] as num?)?.toInt() : null;
      if (c != null) {
        _familyUnread[fid] = c;
        notifyListeners();
      }
    } catch (_) {}
  }

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
        // Giảm badge realtime ngay (socket cũng sẽ đẩy unread-count sau).
        final cur = _familyUnread[fid];
        if (cur != null && cur > 0) _familyUnread[fid] = cur - 1;
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
      _familyUnread[fid] = 0;
      await fetchNotifications();
    } catch (_) {}
  }
}
