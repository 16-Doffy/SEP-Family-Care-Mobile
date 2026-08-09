import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/wallet_provider.dart';

/// Khoá lỗi lệch giờ 7 tiếng ở sổ thu chi — phát hiện khi test flow AI Chatbot
/// tạo giao dịch (`CREATE_LEDGER_ENTRY`), nhưng ảnh hưởng TOÀN BỘ ledger, không
/// riêng giao dịch do AI tạo.
///
/// Bằng chứng runtime 2026-08-07: tạo khoản chi thủ công lúc 20:19 giờ VN
/// (13:19 UTC, verify bằng `adb shell date`/`date -u` trên cả emulator lẫn
/// máy host, TZ = Asia/Bangkok). Sổ thu chi hiện `13:18` — đúng bằng giờ UTC.
///
/// Nguyên nhân là FE tự làm sai dữ liệu của chính mình, chứng minh bằng vòng
/// khép kín: `WalletProvider.recordEntry` gửi `entryDate` bằng
/// `DateTime.now().toUtc().toIso8601String()` (UTC chuẩn) lúc TẠO, nhưng
/// `displayEntryDate` cũ lại cắt bỏ `Z` rồi parse như giờ naive lúc HIỂN THỊ —
/// không phải lỗi BE.
void main() {
  group('LedgerEntry.displayEntryDate — entryDate là UTC thật', () {
    test('chuỗi có Z phải đổi sang giờ local, không đọc thẳng số UTC', () {
      // 13:19 UTC phải hiện thành giờ local của máy chạy test, không phải
      // "13:19" nguyên xi (đó chính là bug: hiện đúng bằng số UTC).
      final utcInstant = DateTime.utc(2026, 8, 7, 13, 19);
      final entry = LedgerEntry(
        id: 'e1',
        entryType: 'EXPENSE',
        amount: 12345,
        description: 'Chi tiêu',
        entryDate: utcInstant.toIso8601String(),
      );

      final expectedLocal = utcInstant.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      final expected =
          '${two(expectedLocal.day)}/${two(expectedLocal.month)}/${expectedLocal.year} '
          '${two(expectedLocal.hour)}:${two(expectedLocal.minute)}';

      expect(entry.displayEntryDate, expected);
      // Không hard-code lệch múi giờ máy CI — chỉ khẳng định KHÔNG in thẳng số
      // UTC khi giờ local thật sự khác UTC (múi giờ +0 thì hai giá trị trùng,
      // bỏ qua assert này).
      if (expectedLocal.hour != utcInstant.hour) {
        expect(entry.displayEntryDate, isNot(contains('13:19')));
      }
    });

    test('chuỗi naive không Z thì giữ nguyên, không tự cộng trừ giờ', () {
      final entry = LedgerEntry(
        id: 'e2',
        entryType: 'EXPENSE',
        amount: 1000,
        description: 'Dữ liệu cũ',
        entryDate: '2026-08-07T20:19:00.000',
      );
      expect(entry.displayEntryDate, '07/08/2026 20:19');
    });

    test(
      'chuỗi rỗng hoặc không parse được thì trả nguyên văn, không crash',
      () {
        final entry = LedgerEntry(
          id: 'e3',
          entryType: 'EXPENSE',
          amount: 1,
          description: '',
          entryDate: 'không-phải-ngày',
        );
        expect(entry.displayEntryDate, 'không-phải-ngày');
      },
    );
  });
}
