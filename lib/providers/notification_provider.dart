import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map : {};
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? data['title']?.toString() ?? 'Thông báo',
      body: json['body']?.toString() ?? json['message']?.toString() ?? data['body']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRead: json['isRead'] as bool? ?? json['read'] as bool? ?? false,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  String get emoji {
    switch (type.toUpperCase()) {
      case 'TASK': return '🏆';
      case 'FINANCE': return '💰';
      case 'SOS': return '🚨';
      case 'CALENDAR': return '📅';
      case 'FAMILY': return '👨‍👩‍👧‍👦';
      default: return '🔔';
    }
  }

  Color get bgColor {
    switch (type.toUpperCase()) {
      case 'TASK': return const Color(0xFFDCFCE7);
      case 'FINANCE': return const Color(0xFFFEF3C7);
      case 'SOS': return const Color(0xFFFEE2E2);
      case 'CALENDAR': return const Color(0xFFEFF6FF);
      default: return const Color(0xFFF9FAFB);
    }
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
      final list = data is List
          ? data
          : data is Map && data['items'] is List
              ? data['items'] as List
              : <dynamic>[];
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
              ))
          .toList();
      notifyListeners();
    } catch (_) {}
  }
}
