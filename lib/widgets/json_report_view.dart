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
  }) : _depth = depth,
       super();

  /// Nhãn tiếng Việt cho tên field BE.
  ///
  /// Áp dụng cho **mọi** nơi dùng widget này, không riêng màn tài chính. Trước
  /// đây map này chỉ được tra khi `financeReportMode == true`, nên Trợ lý AI /
  /// Phần thưởng / Hỗ trợ / SOS rơi hết về [_labelize] và hiện nhãn tiếng Anh
  /// sinh từ tên field ("Total Expense", "Active Budget Plan", "Period Start"…)
  /// ngay trên màn người dùng thường thấy. Key nào chưa có ở đây vẫn rơi về
  /// [_labelize] — thêm dần khi gặp field mới.
  static const _labels = <String, String>{
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
    // `varianceAmount = actualAmount − plannedAmount` (BE) — âm nghĩa là còn
    // dư, dương nghĩa là đã vượt. Nhãn cũ "Còn lại so với ngân sách" đọc số
    // dương thành "còn thừa" trong khi thực ra đang vượt — xem báo cáo test
    // 2026-08-19. Đổi sang cách nói trung lập, đúng cả hai chiều dấu.
    'varianceAmount': 'Chênh lệch so với ngân sách',
    'thresholdLimit': 'Mốc cảnh báo áp dụng',
    // BE đang set field này theo MỐC CẢNH BÁO (thresholdLimit), không phải
    // theo plannedAmount — verify runtime 2026-08-19 (đã chi 5tr, ngân sách
    // 6tr, mốc 4,5tr ⇒ isOverBudget=true dù chưa vượt ngân sách). Nhãn cũ
    // "Đã vượt ngân sách" nói sai ý; xem B1 trong báo cáo test để BE xác nhận
    // lại ngữ nghĩa field này.
    'isOverBudget': 'Đã vượt mốc cảnh báo',
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
    'type': 'Loại cảnh báo',
    'severity': 'Mức độ',
    'thresholdValue': 'Mốc cảnh báo',
    'actualValue': 'Giá trị thực tế',
    'resolutionNote': 'Ghi chú xử lý',
    'resolvedAt': 'Thời gian xử lý',
    // Bổ sung 2026-08-17 sau khi thấy nhãn tiếng Anh lộ ra ở màn Trợ lý AI.
    'id': 'Mã',
    'balance': 'Số dư',
    'totalIncome': 'Tổng thu',
    'activeBudgetPlan': 'Kế hoạch ngân sách đang dùng',
    'lineCount': 'Số danh mục',
    'usagePercent': 'Đã dùng',
    'budgetAlerts': 'Cảnh báo ngân sách',
    'summary': 'Tóm tắt',
    'title': 'Tiêu đề',
    'description': 'Mô tả',
    'amount': 'Số tiền',
    'count': 'Số lượng',
    'total': 'Tổng',
    'month': 'Tháng',
    'year': 'Năm',
    'jar': 'Hũ',
    'jarName': 'Tên hũ',
    'jars': 'Các hũ',
    'relatedJar': 'Hũ liên quan',
    'currency': 'Đơn vị tiền tệ',
    // Nhãn nhóm khi báo cáo lồng object từng dòng ngân sách — key số ít
    // "budgetLine" khác `lines` (danh sách) đã có nhãn "Danh mục ngân sách".
    'budgetLine': 'Dòng ngân sách',
    'categoryName': 'Tên danh mục',
    'family': 'Gia đình',
    'scope': 'Phạm vi',
    'task': 'Nhiệm vụ',
    'tasks': 'Nhiệm vụ',
    'calendar': 'Lịch',
    'events': 'Sự kiện',
    'finance': 'Tài chính',
    'sos': 'Khẩn cấp',
    'album': 'Ảnh',
    'members': 'Thành viên',
    'memberName': 'Thành viên',
    'generatedAt': 'Tạo lúc',
    'updatedAt': 'Cập nhật lúc',
    'createdAt': 'Tạo lúc',
    'startTime': 'Bắt đầu',
    'endTime': 'Kết thúc',
    'dueDate': 'Hạn chót',
    'assignee': 'Người thực hiện',
    'assigneeName': 'Người thực hiện',
    'reward': 'Phần thưởng',
    'rewardName': 'Tên phần thưởng',
    'points': 'Điểm',
    'priority': 'Mức ưu tiên',
    'progressPercentage': 'Tiến độ',
    'message': 'Nội dung',
    'reason': 'Lý do',
    'location': 'Vị trí',
    'latitude': 'Vĩ độ',
    'longitude': 'Kinh độ',
    'address': 'Địa chỉ',
    'phone': 'Số điện thoại',
    'email': 'Email',
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
    'budgetLineId',
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
    return k.contains('amount') ||
        k.contains('income') ||
        k.contains('expense') ||
        k.contains('spending') ||
        k.contains('total') ||
        k.contains('balance') ||
        k.contains('price') ||
        k.contains('shortage') ||
        k.contains('planned') ||
        k.contains('actual') ||
        k.contains('contribution') ||
        k.contains('threshold') ||
        k.contains('variance');
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
    // Ngày dạng "2026-08-01" (không giờ) parse ra local sẵn, `.toLocal()`
    // không đổi gì; nhưng field timestamp đầy đủ có "Z" (UTC) đổi ngày lệch
    // khi giờ VN đã sang ngày khác — phải quy về local trước khi tách ngày.
    final local = date.isUtc ? date.toLocal() : date;
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  /// Field kiểu "startTime"/"endTime" là một MỐC THỜI GIAN cụ thể, không phải
  /// chỉ ngày — quan sát thật 2026-08-08: Daily Brief hiện "Next Events" với
  /// `startTime`/`endTime` nguyên văn `2026-08-09T02:00:00.0Z` vì bộ nhận diện
  /// ngày cũ (`endsWith('at')`, `contains('date')`...) không khớp tên 2 key
  /// này. Định dạng đủ giờ:phút + đổi sang giờ local.
  static String _fmtDateTime(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final local = date.isUtc ? date.toLocal() : date;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  static final _isoDateTimePattern = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}');

  /// Nhận diện theo HÌNH DẠNG giá trị, không chỉ theo tên key — BE có thể đặt
  /// tên field mới bất kỳ lúc nào (đúng tinh thần đã áp dụng cho
  /// `formatAiPreviewValue` ở màn Trợ lý AI), an toàn vì chuỗi thường (tên,
  /// địa chỉ...) không khớp định dạng ISO datetime này.
  static bool _looksLikeIsoDateTime(String value) =>
      _isoDateTimePattern.hasMatch(value);

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
    'SHORTAGE_RISK' => 'Nguy cơ thiếu hụt',
    'GOAL_AT_RISK' => 'Mục tiêu có nguy cơ không đạt',
    'NON_ESSENTIAL_TOO_HIGH' => 'Chi không thiết yếu quá cao',
    'ACHIEVED' => 'Đã hoàn thành',
    _ => value,
  };

  static String _labelize(String key) {
    // camelCase / snake_case → "Camel Case"
    final spaced = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
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
            .where(
              (e) =>
                  !financeReportMode ||
                  (!_technicalKeys.contains(e.key) &&
                      !(_depth > 0 && e.key == 'lines')),
            )
            .map((e) => _entryRow(e.key, e.value))
            .toList(),
      );
    }
    if (data is List) {
      final list = data as List;
      if (list.isEmpty) return _empty();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list
            .asMap()
            .entries
            .map((e) => _listItem(e.key, e.value))
            .toList(),
      );
    }
    return Text(
      data?.toString() ?? '—',
      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
    );
  }

  Widget _empty() => Text(
    'Không có dữ liệu',
    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
  );

  Widget _entryRow(String key, dynamic value) {
    final isComplex = value is Map || value is List;
    if (isComplex) {
      final label = _labels[key] ?? _labelize(key);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trước đây tiêu đề nhóm (Family/Scope/Task/Calendar...) tô màu
            // xám nhạt (textSecondary) giống hệt nhãn field thường, nhìn không
            // phân biệt được đâu là tiêu đề nhóm — đổi màu nổi bật + gạch chân
            // mảnh để tách nhóm rõ ràng hơn.
            Container(
              padding: const EdgeInsets.only(bottom: 4),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.primary100, width: 1.5),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 6),
              child: JsonReportView._nested(
                data: value,
                financeReportMode: financeReportMode,
                depth: _depth + 1,
              ),
            ),
          ],
        ),
      );
    }
    if (value == null) {
      return _valueRow(key, '—');
    }
    final raw = value.toString();
    final lowerKey = key.toLowerCase();
    // Field CHỈ NGÀY (không giờ) như deadline/periodStart/periodEnd vẫn có
    // thể mang giá trị ISO đầy đủ giờ ("2026-12-31T00:00:00.000Z") — phải
    // loại các key này khỏi nhánh nhận diện "có giờ" bên dưới trước, nếu
    // không `_looksLikeIsoDateTime` bắt trước và in nguyên chuỗi ISO ra màn
    // hình (verify runtime 2026-08-19, `goal_contribution_screen` gặp cùng
    // lỗi hình thái). `contains('date')` bắt luôn các key khác kiểu
    // "dueDate"/"birthDate" chưa được liệt tên riêng.
    final isDateOnlyKey =
        lowerKey == 'deadline' ||
        lowerKey == 'periodstart' ||
        lowerKey == 'periodend' ||
        lowerKey.contains('date');
    final display = lowerKey.contains('percent') || lowerKey.contains('ratio')
        // BE trả số thực chưa làm tròn ("45.1190524") — verify runtime
        // 2026-08-19 ở tiến độ mục tiêu trong báo cáo. Làm tròn 1 chữ số
        // thập phân, giữ nguyên chuỗi gốc nếu không phải số hợp lệ.
        ? '${num.tryParse(raw)?.toStringAsFixed(1) ?? raw}%'
        : value is num && _looksLikeMoney(key)
        ? _fmtMoney(value)
        : !isDateOnlyKey &&
              (lowerKey.contains('time') ||
                  (value is String && _looksLikeIsoDateTime(raw)))
        ? _fmtDateTime(raw)
        : lowerKey.endsWith('at') || isDateOnlyKey
        ? _fmtDate(raw)
        : value is bool
        ? (value ? 'Có' : 'Không')
        : lowerKey == 'status' ||
              lowerKey == 'type' ||
              lowerKey == 'periodtype' ||
              lowerKey == 'categorytype' ||
              lowerKey == 'essentialtype' ||
              lowerKey == 'riskseverity' ||
              lowerKey == 'severity' ||
              lowerKey == 'alerttype'
        ? _fmtStatus(raw)
        : _sanitizeText(raw);
    return _valueRow(key, display);
  }

  static String _sanitizeText(String value) {
    // Report messages sometimes embed internal UUIDs (for example a budget
    // line id). They are not meaningful to a family user and make the report
    // hard to read.
    final cleaned = value.replaceAll(
      RegExp(r'\b[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\b'),
      '',
    );
    return cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
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
              _labels[key] ?? _labelize(key),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
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
      child: Text(
        '• ${value?.toString() ?? '—'}',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }
}
