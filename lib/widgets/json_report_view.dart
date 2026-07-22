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
  final bool financeReportMode;
  final int _depth;

  const JsonReportView({
    super.key,
    required this.data,
    this.financeReportMode = false,
  }) : _depth = 0;

  const JsonReportView._nested({
    required this.data,
    required this.financeReportMode,
    required int depth,
  })  : _depth = depth,
        super();

  static const _financeLabels = <String, String>{
    'budgetPlan': 'Kế hoạch ngân sách',
    'budgetPlanReport': 'Báo cáo ngân sách',
    'goal': 'Mục tiêu tiết kiệm',
    'goalProgressReport': 'Tiến độ mục tiêu',
    'progress': 'Tiến độ',
    'totals': 'Tổng quan',
    'lines': 'Danh mục ngân sách',
    'warnings': 'Cảnh báo',
    'period': 'Kỳ báo cáo',
    'periodStart': 'Từ ngày',
    'periodEnd': 'Đến ngày',
    'planName': 'Tên kế hoạch',
    'goalName': 'Tên mục tiêu',
    'periodType': 'Chu kỳ',
    'status': 'Trạng thái',
    'expectedSharedIncome': 'Thu nhập dự kiến',
    'expectedSharedExpense': 'Chi tiêu dự kiến',
    'plannedIncome': 'Thu nhập kế hoạch',
    'plannedExpense': 'Chi tiêu kế hoạch',
    'actualIncome': 'Thu nhập thực tế',
    'actualExpense': 'Chi tiêu thực tế',
    'plannedBalance': 'Số dư kế hoạch',
    'actualBalance': 'Số dư thực tế',
    'varianceIncome': 'Chênh lệch thu',
    'varianceExpense': 'Chênh lệch chi',
    'targetAmount': 'Số tiền mục tiêu',
    'currentAmount': 'Đã góp',
    'remainingAmount': 'Còn thiếu',
    'progressPercent': 'Tiến độ',
    'daysRemaining': 'Số ngày còn lại',
    'monthlyContributionTarget': 'Mục tiêu góp mỗi tháng',
    'nonEssentialExpense': 'Chi không thiết yếu',
    'totalExpense': 'Tổng chi',
    'nonEssentialRatio': 'Tỷ lệ chi không thiết yếu',
    'byCategory': 'Theo danh mục',
    'byJar': 'Theo quỹ',
    'thresholds': 'Ngưỡng cảnh báo',
    'category': 'Danh mục',
    'name': 'Tên',
    'categoryType': 'Loại danh mục',
    'essentialType': 'Mức độ cần thiết',
    'plannedAmount': 'Ngân sách',
    'thresholdAmount': 'Mốc cảnh báo',
    'thresholdPercent': 'Tỷ lệ cảnh báo',
    'actualAmount': 'Đã chi',
    'varianceAmount': 'Còn lại so với ngân sách',
    'thresholdLimit': 'Mốc cảnh báo áp dụng',
    'isOverBudget': 'Đã vượt ngân sách',
    'deadline': 'Hạn hoàn thành',
    'monthsRemaining': 'Số tháng còn lại',
    'recommendedMonthlyContribution': 'Nên góp mỗi tháng',
    'projectedAmountByDeadline': 'Dự kiến có khi đến hạn',
    'isAchieved': 'Đã đạt mục tiêu',
    'isAtRisk': 'Có nguy cơ không đạt',
    'riskSeverity': 'Mức độ rủi ro',
    'alerts': 'Cảnh báo',
    'note': 'Ghi chú',
    'displayName': 'Người tạo',
    'alertType': 'Loại cảnh báo',
    'severity': 'Mức độ',
    'thresholdValue': 'Mốc cảnh báo',
    'actualValue': 'Giá trị thực tế',
    'resolutionNote': 'Ghi chú xử lý',
    'resolvedAt': 'Thời gian xử lý',
  };

  static const _technicalKeys = <String>{
    'id',
    'familyId',
    'createdAt',
    'updatedAt',
    'createdByMemberId',
    'createdBy',
    'user',
    'avatarUrl',
    'budgetPlanId',
    'categoryId',
    'jarId',
    'financeLedgerId',
    'ledgerEntryId',
    'relatedJarId',
    'goalId',
    'sourceKey',
    'sourceId',
  };

  static bool _looksLikeMoney(String key) {
    final k = key.toLowerCase();
    return k.contains('amount') || k.contains('income') || k.contains('expense') ||
        k.contains('spending') || k.contains('total') || k.contains('balance') ||
        k.contains('price') || k.contains('shortage') || k.contains('planned') ||
        k.contains('actual') || k.contains('contribution') ||
        k.contains('threshold') || k.contains('variance');
  }

  static String _fmtMoney(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  static String _fmtDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _fmtStatus(String value) => switch (value) {
    'DRAFT' => 'Bản nháp',
    'ACTIVE' => 'Đang hoạt động',
    'CLOSED' => 'Đã đóng',
    'CANCELED' => 'Đã hủy',
    'AT_RISK' => 'Có nguy cơ không đạt',
    'ON_TRACK' => 'Đúng tiến độ',
    'COMPLETED' => 'Hoàn thành',
    'MONTHLY' => 'Hàng tháng',
    'QUARTERLY' => 'Hàng quý',
    'YEARLY' => 'Hàng năm',
    'INCOME' => 'Thu nhập',
    'EXPENSE' => 'Chi tiêu',
    'ESSENTIAL' => 'Thiết yếu',
    'NON_ESSENTIAL' => 'Không thiết yếu',
    'NEUTRAL' => 'Trung lập',
    'HIGH' => 'Cao',
    'MEDIUM' => 'Trung bình',
    'LOW' => 'Thấp',
    'NEW' => 'Mới',
    'ACKNOWLEDGED' => 'Đã xem',
    'RESOLVED' => 'Đã xử lý',
    'OVER_BUDGET' => 'Vượt ngân sách',
    'GOAL_AT_RISK' => 'Mục tiêu có nguy cơ không đạt',
    'NON_ESSENTIAL_TOO_HIGH' => 'Chi không thiết yếu quá cao',
    _ => value,
  };

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
        children: map.entries
            .where((e) =>
                !financeReportMode ||
                (!_technicalKeys.contains(e.key) &&
                    !(_depth > 0 && e.key == 'lines')))
            .map((e) => _entryRow(e.key, e.value))
            .toList(),
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
          Text(financeReportMode ? (_financeLabels[key] ?? _labelize(key)) : _labelize(key),
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 4),
            child: JsonReportView._nested(
              data: value,
              financeReportMode: financeReportMode,
              depth: _depth + 1,
            ),
          ),
        ]),
      );
    }
    if (value == null) {
      return _valueRow(key, '—');
    }
    final raw = value.toString();
    final lowerKey = key.toLowerCase();
    final display = lowerKey.contains('percent') || lowerKey.contains('ratio')
        ? '$raw%'
        : value is num && _looksLikeMoney(key)
        ? _fmtMoney(value)
        : lowerKey.endsWith('at') ||
                lowerKey.contains('date') ||
                lowerKey == 'deadline' ||
                lowerKey == 'periodstart' ||
                lowerKey == 'periodend'
        ? _fmtDate(raw)
        : value is bool
        ? (value ? 'Có' : 'Không')
        : lowerKey == 'status' ||
                lowerKey == 'periodtype' ||
                lowerKey == 'categorytype' ||
                lowerKey == 'essentialtype' ||
                lowerKey == 'riskseverity' ||
                lowerKey == 'severity' ||
                lowerKey == 'alerttype'
        ? _fmtStatus(raw)
        : raw;
    return _valueRow(key, display);
  }

  Widget _valueRow(String key, String display) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
                financeReportMode ? (_financeLabels[key] ?? _labelize(key)) : _labelize(key),
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
        child: JsonReportView._nested(
          data: value,
          financeReportMode: financeReportMode,
          depth: _depth + 1,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('• ${value?.toString() ?? '—'}',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
    );
  }
}
