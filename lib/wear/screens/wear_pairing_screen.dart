import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../wear_utils.dart';
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
    final padding = WearUtils.safePadding(context);
    final code = _deviceCode ?? 'FCW-...';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(padding.left, 8, padding.right, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.watch_rounded,
                  size: 28,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lien ket dong ho',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Mo FamilyCare tren dien thoai',
                  style: GoogleFonts.inter(fontSize: 8, color: Colors.white38),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Ma thiet bi',
                        style: GoogleFonts.inter(
                          fontSize: 7,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        code,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Ho so > Thiet bi deo > Ghep thiet bi, nhap ma nay.',
                  style: GoogleFonts.inter(
                    fontSize: 7.5,
                    height: 1.25,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _checking ? null : _checkLink,
                  child: Container(
                    height: 30,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _checking
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: _checking
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Da ghep tren dien thoai',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                // Đường dự phòng: ghép từ điện thoại hiện CHƯA cấp được token
                // cho đồng hồ (không có hợp đồng BE đổi mã lấy token, cũng
                // không có kênh đồng bộ phone↔watch). Không có lối này thì đồng
                // hồ kẹt vĩnh viễn ở màn ghép nối. Bỏ đi khi BE có pairing
                // token exchange.
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WearLoginScreen(),
                    ),
                  ),
                  child: Container(
                    height: 26,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF3A3A3A)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Dang nhap tren dong ho',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
