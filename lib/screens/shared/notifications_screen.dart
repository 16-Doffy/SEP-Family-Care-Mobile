import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      if (diff.inDays == 1) return 'Hom qua';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  String? _firstNonEmptyId(Iterable<String> ids) {
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty && trimmed != 'null') return trimmed;
    }
    return null;
  }

  void _openNotification(AppNotification notification) {
    if (!notification.isRead) {
      context.read<NotificationProvider>().markAsRead(notification.id);
    }

    if (notification.isTask) {
      final canManageTasks =
          context.read<AuthProvider>().user?.canManageTasks ?? false;
      context.go(canManageTasks ? '/manager/tasks' : '/member/tasks');
      return;
    }

    if (notification.isFinance) {
      final canManageFinance =
          context.read<AuthProvider>().user?.canManageSharedFinance ?? false;
      context.go(canManageFinance ? '/manager/finance' : '/member/wallet');
      return;
    }

    if (!notification.isSos) return;

    final explicitId = notification.referenceId?.trim();
    final fallbackId = _firstNonEmptyId([
      ...context.read<SosProvider>().activeAlerts,
      ...context.read<SosProvider>().alerts,
    ].map((a) => a.id));
    final alertId = (explicitId != null &&
            explicitId.isNotEmpty &&
            explicitId != 'null')
        ? explicitId
        : fallbackId;

    if (alertId != null && alertId.isNotEmpty) {
      context.push('/sos/alert/$alertId');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chưa tìm thấy chi tiết cảnh báo SOS'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Thông báo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (provider.unreadCount > 0)
                    GestureDetector(
                      onTap: () => provider.markAllAsRead(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.done_all_rounded,
                          size: 18,
                          color: AppColors.link,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => provider.fetchNotifications(),
                      child: provider.notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '\u{1F514}',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Chưa có thông báo nào',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: provider.notifications.length,
                              itemBuilder: (_, i) {
                                final n = provider.notifications[i];
                                return GestureDetector(
                                  onTap: () => _openNotification(n),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: n.bgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: n.isRead
                                          ? null
                                          : Border.all(
                                              color:
                                                  AppColors.link.withOpacity(0.3),
                                            ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          n.emoji,
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                n.title,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: n.isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.w700,
                                                  color:
                                                      AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                n.body,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatTime(n.createdAt),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
