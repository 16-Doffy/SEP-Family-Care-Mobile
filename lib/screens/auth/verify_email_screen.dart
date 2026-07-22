import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

// UC-ONBOARD — Xác thực email bằng OTP 6 số, chèn giữa Register và
// FamilySetupScreen (POST /families trả 403 nếu account chưa verify, xem
// AuthProvider.createFamily / computeRedirect trong app_router.dart).
class VerifyEmailScreen extends StatefulWidget {
  final String? returnTo;

  const VerifyEmailScreen({super.key, this.returnTo});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _digitCount = 6;
  final _controllers = List.generate(
    _digitCount,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_digitCount, (_) => FocusNode());

  bool _verifying = false;
  String? _error;

  bool _resending = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() => _error = null);
    if (value.isNotEmpty && index < _digitCount - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_code.length == _digitCount) {
      _verify();
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verify() async {
    final code = _code;
    if (code.length != _digitCount || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().verifyEmail(code);
      if (mounted) {
        final target = widget.returnTo;
        if (target != null && target.isNotEmpty && target != '/verify-email') {
          context.go(target);
        } else {
          final auth = context.read<AuthProvider>();
          if (auth.hasFamily) {
            context.go(switch (auth.user?.role) {
              UserRole.manager => '/manager/home',
              UserRole.deputy => '/deputy/home',
              _ => '/member/home',
            });
          } else {
            context.go('/family-setup');
          }
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.statusCode == 400
              ? 'Mã OTP không đúng hoặc đã hết hạn'
              : e.message,
        );
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes.first.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().resendVerificationCode();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã gửi lại mã OTP tới email của bạn'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _startCooldown();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.statusCode == 400
              ? 'Vui lòng đợi trước khi gửi lại mã'
              : e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email ?? '';
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 64,
                  color: AppColors.primary500,
                ),
                const SizedBox(height: 20),
                Text(
                  'Xác thực email',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email.isEmpty
                      ? 'Nhập mã OTP 6 số vừa được gửi tới email của bạn'
                      : 'Nhập mã OTP 6 số vừa được gửi tới\n$email',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _digitCount,
                    (i) => Padding(
                      padding: EdgeInsets.only(
                        right: i < _digitCount - 1 ? 10 : 0,
                      ),
                      child: _digitBox(i),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.danger,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.link,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: (_verifying || _code.length != _digitCount)
                        ? null
                        : _verify,
                    child: _verifying
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Xác thực',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed: (_resending || _cooldown > 0) ? null : _resend,
                  child: _resending
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _cooldown > 0
                              ? 'Gửi lại mã sau ${_cooldown}s'
                              : 'Gửi lại mã OTP',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _cooldown > 0
                                ? AppColors.textMuted
                                : AppColors.link,
                          ),
                        ),
                ),

                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (mounted) context.go('/login');
                  },
                  child: Text(
                    'Đăng xuất',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
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

  Widget _digitBox(int index) {
    return SizedBox(
      width: 44,
      height: 54,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty) {
            _onBackspace(index);
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.white,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _error != null
                    ? AppColors.danger
                    : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.link, width: 2),
            ),
          ),
          onChanged: (v) => _onDigitChanged(index, v),
          onTap: () =>
              _controllers[index].selection = TextSelection.fromPosition(
                TextPosition(offset: _controllers[index].text.length),
              ),
        ),
      ),
    );
  }
}
