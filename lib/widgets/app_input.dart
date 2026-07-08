import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'money_input.dart';

/// Ô nhập chuẩn của app: label + viền bo tròn + lỗi inline đỏ dưới ô.
/// Dùng trong Form để validator hoạt động.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.money = false,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final bool money;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscure,
          maxLines: maxLines,
          keyboardType: money ? TextInputType.number : keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          inputFormatters: money ? const [ThousandsSeparatorInputFormatter()] : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: money ? '₫' : null,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: AppColors.textMuted)
                : null,
            suffixIcon: suffix,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// Ô chọn ngày: chạm mở lịch, hiển thị dd/MM/yyyy, value gửi BE là yyyy-MM-dd.
class AppDateField extends StatefulWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialIso,
    this.hint = 'Chạm để chọn ngày',
    this.firstDate,
    this.lastDate,
    this.validator,
  });

  final String label;
  /// Nhận giá trị ISO yyyy-MM-dd mỗi khi chọn ngày
  final ValueChanged<String> onChanged;
  final String? initialIso;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? Function(String?)? validator;

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  late final TextEditingController _ctrl;
  String _iso = '';

  @override
  void initState() {
    super.initState();
    _iso = widget.initialIso ?? '';
    _ctrl = TextEditingController(text: _display(_iso));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _display(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_iso) ?? now,
      firstDate: widget.firstDate ?? DateTime(now.year - 1),
      lastDate: widget.lastDate ?? DateTime(now.year + 20),
    );
    if (picked == null) return;
    _iso = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _ctrl.text = _display(_iso));
    widget.onChanged(_iso);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(widget.label,
              style: GoogleFonts.inter(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        TextFormField(
          controller: _ctrl,
          readOnly: true,
          onTap: _pick,
          validator: widget.validator == null ? null : (_) => widget.validator!(_iso),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// Nút chính của app: full-width, bo tròn, có trạng thái loading.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary500,
          disabledBackgroundColor: (color ?? AppColors.primary500).withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
      ),
    );
  }
}
