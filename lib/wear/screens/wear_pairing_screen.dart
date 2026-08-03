import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../wear_widgets.dart';
import 'wear_login_screen.dart';

class WearPairingScreen extends StatefulWidget {
  const WearPairingScreen({super.key});

  @override
  State<WearPairingScreen> createState() => _WearPairingScreenState();
}

class _WearPairingScreenState extends State<WearPairingScreen> {
  static const _storage = FlutterSecureStorage();
  static const _deviceCodeKey = 'wear_device_pairing_code';

  String? _deviceCode;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceCode();
  }

  Future<void> _loadDeviceCode() async {
    var code = await _storage.read(key: _deviceCodeKey);
    if (code == null || code.isEmpty) {
      code = _newDeviceCode();
      await _storage.write(key: _deviceCodeKey, value: code);
    }
    if (mounted) setState(() => _deviceCode = code);
  }

  String _newDeviceCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random(DateTime.now().microsecondsSinceEpoch);
    final body = List.generate(
      6,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
    return 'FCW-$body';
  }

  Future<void> _checkLink() async {
    HapticFeedback.lightImpact();
    setState(() => _checking = true);
    try {
      await context.read<AuthProvider>().tryRestoreSession();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _deviceCode ?? 'FCW-...';

    return WearPage(
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.watch_rounded, size: 30, color: WearPalette.green),
          const SizedBox(height: 7),
          const Text(
            'Kết nối mobile',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: WearPalette.text,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Nhập mã này trên FamilyCare',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8.5, color: WearPalette.faint),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: WearPalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: WearPalette.line),
            ),
            child: Column(
              children: [
                const Text(
                  'Mã thiết bị',
                  style: TextStyle(fontSize: 7.5, color: WearPalette.faint),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: WearPalette.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          WearPillButton(
            label: 'Đã ghép trên mobile',
            icon: Icons.sync_rounded,
            color: WearPalette.green,
            loading: _checking,
            onTap: _checkLink,
          ),
          const SizedBox(height: 7),
          WearPillButton(
            label: 'Đăng nhập tạm',
            icon: Icons.login_rounded,
            color: WearPalette.faint,
            outlined: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WearLoginScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
