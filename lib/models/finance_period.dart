/// Kỳ tài chính theo tháng — đơn vị chung cho mọi màn Finance.
///
/// Trước 2026-08-02 mỗi màn tự gọi `DateTime.now()` rồi tách `month`/`year`,
/// nên qua mốc chuyển tháng toàn bộ số liệu tháng cũ không còn truy cập được từ
/// UI. Mọi provider/screen tài chính giờ nhận kỳ qua kiểu này thay vì tự đọc
/// đồng hồ hệ thống.
class FinancePeriod implements Comparable<FinancePeriod> {
  const FinancePeriod(this.year, this.month);

  factory FinancePeriod.current() {
    final now = DateTime.now();
    return FinancePeriod(now.year, now.month);
  }

  final int year;
  final int month;

  /// Ngày đầu kỳ — dùng cho query `periodStart`.
  DateTime get start => DateTime(year, month, 1);

  /// Ngày cuối kỳ. `DateTime(y, m + 1, 0)` tự chuẩn hóa cả tháng 12 lẫn năm
  /// nhuận, không cần bảng số ngày.
  DateTime get end => DateTime(year, month + 1, 0);

  /// `2026-08-01` — định dạng BE nhận cho `periodStart`/`periodEnd`.
  String get startIso => _isoDate(start);
  String get endIso => _isoDate(end);

  FinancePeriod get previous =>
      month == 1 ? FinancePeriod(year - 1, 12) : FinancePeriod(year, month - 1);

  FinancePeriod get next =>
      month == 12 ? FinancePeriod(year + 1, 1) : FinancePeriod(year, month + 1);

  bool get isCurrent => this == FinancePeriod.current();

  /// Kỳ đã kết thúc — dữ liệu không thể phát sinh thêm.
  bool get isPast => compareTo(FinancePeriod.current()) < 0;

  /// Nhãn ngắn cho chip/nút: `8/2026`.
  String get shortLabel => '$month/$year';

  /// Nhãn đầy đủ cho tiêu đề: `Tháng 8/2026`.
  String get label => 'Tháng $month/$year';

  /// Ngày `d` có nằm trong kỳ này không — dùng để lọc dữ liệu đã tải sẵn.
  bool contains(DateTime d) => d.year == year && d.month == month;

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  int compareTo(FinancePeriod other) =>
      year == other.year ? month - other.month : year - other.year;

  @override
  bool operator ==(Object other) =>
      other is FinancePeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'FinancePeriod($year-$month)';
}
