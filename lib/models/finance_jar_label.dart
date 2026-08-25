/// Dịch tên hũ tài chính sang tiếng Việt để hiển thị.
///
/// **Vì sao cần file này:** với mô hình `FIVE_JARS` / `EIGHTY_TWENTY`, **BE tự
/// tạo sẵn các hũ kèm tên tiếng Anh** (`Necessities`, `Savings`, `Education`,
/// `Enjoyment`, `Giving`, `Spending`) — FE lúc áp mô hình chỉ PATCH lại
/// `allocationPercentage`, không đụng tới `name` (xem
/// `finance_model_screen.dart`, nhánh "BE đã tự tạo jar mặc định"). Hệ quả:
/// màn "Mô hình tài chính" hiện tiếng Việt vì nó dùng danh sách UI hardcode
/// riêng, còn mọi màn khác (Sổ thu chi, Báo cáo tài chính, Gán danh mục vào hũ)
/// hiện thẳng tên thô từ BE nên ra tiếng Anh.
///
/// Cách sửa ở đây là **chỉ đổi lúc hiển thị**, không ghi đè tên trong DB của
/// BE: gia đình nào tự đặt tên hũ riêng thì giữ nguyên tên họ đặt.
library;

/// Bảng dịch theo `jarCode` — nguồn tin cậy nhất vì mã do BE định nghĩa cố định,
/// không đổi theo ngôn ngữ hay theo việc người dùng sửa tên.
const Map<String, String> _byJarCode = {
  'NECESSITIES': 'Nhu cầu thiết yếu',
  'SAVINGS': 'Tiết kiệm',
  'EDUCATION': 'Giáo dục',
  'ENJOYMENT': 'Vui chơi',
  'GIVING': 'Cho đi / Biếu tặng',
  'SPENDING': 'Chi tiêu',
};

/// Bảng dịch theo **tên tiếng Anh** BE đặt sẵn — lưới đỡ cho trường hợp response
/// không kèm `jarCode` (một số endpoint chỉ trả `jarName`), và cho các chuỗi BE
/// tự ghép sẵn (xem [localizeJarNamesInText]).
const Map<String, String> _byEnglishName = {
  'necessities': 'Nhu cầu thiết yếu',
  'savings': 'Tiết kiệm',
  'saving': 'Tiết kiệm',
  'education': 'Giáo dục',
  'enjoyment': 'Vui chơi',
  'giving': 'Cho đi / Biếu tặng',
  'spending': 'Chi tiêu',
  'long term savings': 'Tiết kiệm dài hạn',
  'financial freedom': 'Tự do tài chính',
  'play': 'Vui chơi',
  'necessity': 'Nhu cầu thiết yếu',
};

/// Tên hũ để hiển thị cho người dùng.
///
/// Ưu tiên [jarCode] (BE định nghĩa cố định) → tên tiếng Anh mặc định của BE →
/// giữ nguyên [rawName]. Gia đình tự đặt tên hũ (mô hình `CUSTOM`, hoặc sửa tên
/// hũ mặc định) sẽ **không bị đổi** vì không khớp bảng nào.
String jarDisplayName(String? jarCode, String? rawName) {
  final code = (jarCode ?? '').trim().toUpperCase();
  final byCode = _byJarCode[code];
  if (byCode != null) return byCode;

  final name = (rawName ?? '').trim();
  if (name.isEmpty) return code.isEmpty ? 'Hũ tài chính' : code;

  final byName = _byEnglishName[name.toLowerCase()];
  if (byName != null) return byName;

  return name;
}

/// Dịch tên hũ tiếng Anh **nằm bên trong một câu do BE ghép sẵn**.
///
/// Ví dụ thật đo trên máy: sổ thu chi hiện `"Chia quỹ vào hũ Giving"` —
/// `description` là chuỗi hoàn chỉnh BE trả về, FE không dựng lại được nên phải
/// thay đúng phần tên hũ. Chỉ thay khi khớp **trọn từ** (dùng ranh giới từ) để
/// không cắt nhầm chữ nằm trong từ khác.
///
/// ⚠️ Đây là vá phía hiển thị. Đúng ra BE nên trả tên hũ theo ngôn ngữ của app
/// (hoặc trả `jarId`/`jarCode` để FE tự dựng câu) — đã ghi vào `API_DOCS.md`
/// mục cần báo BE.
String localizeJarNamesInText(String? text) {
  final input = text ?? '';
  if (input.isEmpty) return input;
  var out = input;
  for (final entry in _byEnglishName.entries) {
    out = out.replaceAllMapped(
      RegExp('\\b${RegExp.escape(entry.key)}\\b', caseSensitive: false),
      (_) => entry.value,
    );
  }
  return out;
}
