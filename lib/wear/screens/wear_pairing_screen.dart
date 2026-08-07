import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/wearable_provider.dart';
import '../../services/api_client.dart';
import '../wear_widgets.dart';
import 'wear_login_screen.dart';

class WearPairingScreen extends StatefulWidget {
  const WearPairingScreen({super.key});

  @override
  State<WearPairingScreen> createState() => _WearPairingScreenState();
}

class _WearPairingScreenState extends State<WearPairingScreen> {
  static const _maxSilentPollErrors = 3;

  Timer? _pollTimer;
  WearableActivation? _activation;
  bool _creating = true;
  bool _checking = false;
  bool _claiming = false;
  int _pollErrorCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _createActivation());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createActivation() async {
    _pollTimer?.cancel();
    setState(() {
      _creating = true;
      _checking = false;
      _claiming = false;
      _pollErrorCount = 0;
      _error = null;
      _activation = null;
    });
    try {
      final activation = await context
          .read<WearableProvider>()
          .createActivation(deviceName: 'Wear OS', deviceType: 'SMARTWATCH');
      if (!mounted) return;
      setState(() => _activation = activation);
      _startPolling();
    } catch (e) {
      if (mounted) setState(() => _error = _activationErrorMessage(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkStatus(silent: true),
    );
  }

  Future<void> _checkStatus({bool silent = false}) async {
    final sessionId = _activation?.sessionId;
    if (sessionId == null || sessionId.isEmpty || _claiming) return;
    if (!silent) HapticFeedback.lightImpact();
    if (!silent) setState(() => _checking = true);
    try {
      final next = await context.read<WearableProvider>().fetchActivationStatus(
        sessionId,
      );
      if (!mounted) return;
      setState(() {
        _activation = next;
        _pollErrorCount = 0;
        _error = null;
      });
      if (next.isPaired) await _claim(sessionId);
      if (next.isClaimed || next.isExpired) _pollTimer?.cancel();
      if (!silent && next.isPending && !(_pollTimer?.isActive ?? false)) {
        _startPolling();
      }
    } catch (e) {
      if (!mounted) return;
      final message = _activationErrorMessage(e);
      if (silent) {
        _pollErrorCount += 1;
        if (_pollErrorCount >= _maxSilentPollErrors) {
          _pollTimer?.cancel();
          setState(() => _error = message);
        }
      } else {
        setState(() => _error = message);
      }
    } finally {
      if (mounted && !silent) setState(() => _checking = false);
    }
  }

  Future<void> _claim(String sessionId) async {
    _pollTimer?.cancel();
    if (_claiming) return;
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().claimWearableActivation(sessionId);
    } catch (e) {
      if (mounted) setState(() => _error = _activationErrorMessage(e));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  String _activationErrorMessage(Object error) {
    if (error is ApiException) {
      final code = error.code?.toUpperCase();
      if (code == 'ACTIVATION_NOT_PAIRED') {
        return 'Mã này chưa được ghép trên điện thoại.';
      }
      if (code == 'ACTIVATION_ALREADY_CLAIMED') {
        return 'Phiên ghép này đã được dùng. Hãy tạo mã mới.';
      }
      if (code == 'ACTIVATION_EXPIRED') {
        return 'Mã đã hết hạn. Hãy tạo mã mới.';
      }
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
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
            'Nhập mã này trên điện thoại để ghép đồng hồ',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8.5, color: WearPalette.faint),
          ),
          const SizedBox(height: 10),
          _codeCard(),
          const SizedBox(height: 9),
          WearPillButton(
            label: _activation?.isExpired == true ? 'Tạo mã mới' : 'Kiểm tra',
            icon: Icons.sync_rounded,
            color: WearPalette.green,
            loading: _creating || _checking || _claiming,
            onTap: _activation?.isExpired == true
                ? _createActivation
                : () => _checkStatus(),
          ),
          const SizedBox(height: 7),
          // Đường dự phòng khi activation API chưa sẵn sàng trên môi trường demo.
          WearPillButton(
            label: 'Đăng nhập mật khẩu',
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

  Widget _codeCard() {
    final activation = _activation;
    final code = activation?.code;
    final status = activation?.status.toUpperCase();
    final title = _creating
        ? 'Đang tạo mã'
        : code == null || code.isEmpty
        ? 'Chưa có mã'
        : code;
    final subtitle = _error != null
        ? _error!
        : _claiming
        ? 'Đã ghép, đang lấy phiên...'
        : status == 'PAIRED'
        ? 'Đã ghép, đang xác thực'
        : status == 'CLAIMED'
        ? 'Đã xác thực'
        : activation?.isExpired == true
        ? 'Mã đã hết hạn'
        : 'Profile > Thiết bị đeo';
    final color = _error != null || activation?.isExpired == true
        ? WearPalette.amber
        : WearPalette.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: WearPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WearPalette.line),
      ),
      child: Column(
        children: [
          Text(
            'Mã đồng hồ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8, color: WearPalette.faint),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8, color: WearPalette.faint),
          ),
        ],
      ),
    );
  }
}
