import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

// Hiển thị report trả về từ BE dạng key-value đệ quy — dùng cho các endpoint
// report Finance (budget-plan report, non-essential-spending, budget-goal)
// mà Swagger KHÔNG document response schema (chỉ ghi mô tả ngắn). Tránh đoán
// sai tên field: hiển thị đúng những gì BE trả về, format số tiền/ngày nếu
// nhận diện được theo tên key, còn lại in nguyên giá trị.
class JsonReportView extends StatelessWidget {
  final dynamic data;
  const JsonReportView({super.key, required this.data});

  static bool _looksLikeMoney(String key) {
    final k = key.toLowerCase();
    return k.contains('amount') || k.contains('income') || k.contains('expense') ||
        k.contains('spending') || k.contains('total') || k.contains('balance') ||
        k.contains('price') || k.contains('shortage') || k.contains('planned') ||
        k.contains('actual');
  }

  static String _fmtMoney(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  static String _labelize(String key) {
    // camelCase / snake_case → "Camel Case"
    final spaced = key
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data as Map);
      if (map.isEmpty) return _empty();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: map.entries.map((e) => _entryRow(e.key, e.value)).toList(),
      );
    }
    if (data is List) {
      final list = data as List;
      if (list.isEmpty) return _empty();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list.asMap().entries.map((e) => _listItem(e.key, e.value)).toList(),
      );
    }
    return Text(data?.toString() ?? '—',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary));
  }

  Widget _empty() => Text('Không có dữ liệu',
      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted));

  Widget _entryRow(String key, dynamic value) {
    final isComplex = value is Map || value is List;
    if (isComplex) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_labelize(key),
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 4),
            child: JsonReportView(data: value),
          ),
        ]),
      );
    }
    final display = (value is num && _looksLikeMoney(key)) ? _fmtMoney(value) : (value?.toString() ?? '—');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(_labelize(key),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            flex: 4,
            child: Text(display,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _listItem(int index, dynamic value) {
    if (value is Map || value is List) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: JsonReportView(data: value),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('• ${value?.toString() ?? '—'}',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
    );
  }
}
