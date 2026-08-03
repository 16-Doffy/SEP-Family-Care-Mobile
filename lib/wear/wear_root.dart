import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_provider.dart';
import '../services/local_notification_service.dart';
import '../services/push_service.dart';
import 'screens/wear_home_screen.dart';
import 'screens/wear_notifications_screen.dart';
import 'screens/wear_pairing_screen.dart';
import 'screens/wear_quick_message_screen.dart';

class WearRoot extends StatefulWidget {
  const WearRoot({super.key});

  @override
  State<WearRoot> createState() => _WearRootState();
}

class _WearRootState extends State<WearRoot> {
  bool _liveStarted = false;
  NotificationProvider? _notifications;
  ChatProvider? _chat;

  @override
  void dispose() {
    _stopLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.restoring) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFDC2626),
            ),
          ),
        ),
      );
    }
    if (auth.isLoggedIn) {
      _startLiveOnce();
      return const WearHomeScreen();
    }
    _stopLive();
    return const WearPairingScreen();
  }

  void _startLiveOnce() {
    if (_liveStarted) return;
    _liveStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!context.read<AuthProvider>().isLoggedIn) {
        _liveStarted = false;
        return;
      }
      final notifications = context.read<NotificationProvider>();
      final chat = context.read<ChatProvider>();
      _notifications = notifications;
      _chat = chat;
      notifications.onTransient = _showWearNotification;
      await LocalNotificationService.instance.init();
      if (!mounted) return;
      PushService.instance
        ..onTapPayload = _openFromNotification
        ..start();
      notifications
        ..fetchUnreadCount()
        ..startRealtime()
        ..fetchNotifications();

      await chat.openDefaultConversation();
      chat.startPolling();
    });
  }

  void _stopLive() {
    if (!_liveStarted) return;
    _liveStarted = false;
    final notifications = _notifications;
    if (notifications == null) return;
    if (notifications.onTransient == _showWearNotification) {
      notifications.onTransient = null;
    }
    notifications.stopRealtime();
    _chat?.stopPolling();
  }

  void _showWearNotification(AppNotification n) {
    LocalNotificationService.instance.show(
      title: n.title.isEmpty ? 'FamilyCare' : n.title,
      body: n.body,
      isSos: n.type == 'SOS',
      payload: '${n.referenceType ?? n.type}|${n.referenceId ?? ''}',
      badgeNumber: context.read<NotificationProvider>().unreadCount,
    );
  }

  void _openFromNotification(String payload) {
    if (!mounted) return;
    final type = payload.split('|').first.toUpperCase();
    final target = type.contains('CHAT') || type.contains('MESSAGE')
        ? const WearQuickMessageScreen()
        : const WearNotificationsScreen();
    Navigator.maybeOf(
      context,
    )?.push(MaterialPageRoute<void>(builder: (_) => target));
  }
}

class WearNavigatorRoot extends StatelessWidget {
  const WearNavigatorRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const WearRoot(),
      ),
    );
  }
}
