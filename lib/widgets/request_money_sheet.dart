import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/money_provider.dart';
import 'money_input.dart';
import '../theme/app_colors.dart';

class RequestMoneySheet extends StatefulWidget {
  const RequestMoneySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const RequestMoneySheet(),
    );
  }

  @override
  State<RequestMoneySheet> createState() => _RequestMoneySheetState();
}

class _RequestMoneySheetState extends State<RequestMoneySheet> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _triedSubmit = false;
  bool _submitting = false;

  static const _presets = [20000, 50000, 100000, 200000];
  static const _minAmount = 1000;
  static const _maxAmount = 10000000;

  int get _amount => parseMoneyInput(_amountCtrl.text).round();
  bool get _isValid => _amount >= _minAmount && _amount <= _maxAmount;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _fmt(int value) {
    final text = value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$text đ';
  }

  String? _amountError() {
    if (!_triedSubmit) return null;
    if (_amount <= 0) return 'Nhập số tiền cần hỗ trợ';
    if (_amount < _minAmount) return 'Tối thiểu ${_fmt(_minAmount)}';
    if (_amount > _maxAmount) return 'Tối đa ${_fmt(_maxAmount)} mỗi lần';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);
    if (!_isValid || _submitting) return;

    final messenger = ScaffoldMessenger.of(context);
    final money = context.read<MoneyProvider>();
    final amount = _amount;
    final reason = _reasonCtrl.text.trim().isEmpty
        ? 'Hỗ trợ chi tiêu'
        : _reasonCtrl.text.trim();

    setState(() => _submitting = true);
    try {
      await money.addRequest(amount: amount.toDouble(), purpose: reason);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã gửi yêu cầu hỗ trợ ${_fmt(amount)}'),
          backgroundColor: AppColors.safe,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = _amountError();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.progressTrack,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Yêu cầu hỗ trợ chi tiêu',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Gửi yêu cầu để manager hoặc deputy xem xét',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                final active = _amount == preset;
                return ChoiceChip(
                  selected: active,
                  label: Text(_fmt(preset)),
                  onSelected: (_) {
                    setState(() => _amountCtrl.text =
                        ThousandsSeparatorInputFormatter.formatThousands(preset.toString()));
                  },
                  selectedColor: AppColors.primary500,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.primary600,
                  ),
                  backgroundColor: AppColors.primary50,
                  side: BorderSide(
                    color: active ? AppColors.primary500 : AppColors.progressTrack,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Số tiền',
                suffixText: 'đ',
                errorText: err,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLength: 120,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Mục đích',
                hintText: 'VD: mua sách, ăn sáng, di chuyển...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isValid ? AppColors.primary500 : AppColors.progressTrack,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isValid ? 'Gửi yêu cầu' : 'Nhập số tiền',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _isValid ? Colors.white : AppColors.textMuted,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
