import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../providers/wearable_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

@visibleForTesting
String debugMaskedToken(String? token) {
  final value = token ?? '';
  if (value.isEmpty) return 'Không có';
  final prefixLength = value.length < 6 ? value.length : 6;
  return '${value.substring(0, prefixLength)}… (${value.length} ký tự)';
}

class DebugStatusScreen extends StatefulWidget {
  const DebugStatusScreen({super.key});

  @override
  State<DebugStatusScreen> createState() => _DebugStatusScreenState();
}

class _DebugStatusScreenState extends State<DebugStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WearableProvider>().fetchCurrentDevice();
      context.read<SosProvider>().fetchAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          'Debug nội bộ',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Consumer3<AuthProvider, WearableProvider, SosProvider>(
          builder: (context, auth, wearable, sos, _) {
            final user = auth.user;
            final device = wearable.currentDevice;
            final activeAlerts = sos.activeAlerts;
            final firstActive = activeAlerts.isEmpty
                ? null
                : activeAlerts.first;
            final lastError = sos.error ?? wearable.error ?? 'Không có';

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _section(
                  title: 'Phiên đăng nhập',
                  children: [
                    _row('userId', user?.id ?? 'Không có'),
                    _row('familyId', user?.familyId ?? 'Không có'),
                    _row('familyRole', user?.familyRoleString ?? 'Không có'),
                    _row('accessToken', debugMaskedToken(user?.accessToken)),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Wearable',
                  children: [
                    _row('deviceId', device?.id ?? 'Không có'),
                    _row(
                      'deviceIdentifier',
                      device?.deviceIdentifier.isNotEmpty == true
                          ? device!.deviceIdentifier
                          : 'Không có',
                    ),
                    _row('pairingStatus', device?.pairingStatus ?? 'Không có'),
                    _row(
                      'lastSeenAt',
                      device?.lastSeenAt?.toIso8601String() ?? 'Không có',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'SOS',
                  children: [
                    _row('ACTIVE count', activeAlerts.length.toString()),
                    _row('alertId', firstActive?.id ?? 'Không có'),
                    _row('status', firstActive?.status ?? 'Không có'),
                    _row('sender', firstActive?.senderName ?? 'Không có'),
                    _row('createdAt', firstActive?.createdAt ?? 'Không có'),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Lỗi API gần nhất',
                  children: [
                    _row('message', lastError, danger: lastError != 'Không có'),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool danger = false}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: danger ? AppColors.danger : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
