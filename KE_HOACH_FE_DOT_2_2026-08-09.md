# Kế hoạch FE đợt 2 — giao cho Codex

Ngày: **2026-08-09** · Nhánh `giap` (ahead 24 so với `origin/giap`, chưa push)
Trạng thái lúc soạn: `flutter analyze --no-fatal-infos` 0 error / 0 warning · `flutter test` **309/309 pass**

Đây là bản lọc từ roadmap 8 mục của Codex theo hai tiêu chí:

1. **Không phụ thuộc việc test tay của người dùng** — chỉ nhận việc code/tài liệu tự kiểm chứng được bằng `analyze` + `test`.
2. **Không làm mất ổn định hệ thống** — không đụng vùng Duy đang làm dở, không đổi luồng đã chạy ổn định.

Phần bị loại và **lý do loại** nằm ở cuối file. Đọc phần đó trước khi thắc mắc "sao thiếu mục X".

---

# NHÓM A — Làm ngay

## A1. Chốt dứt điểm tràn màn đếm ngược, và thay việc rà tay bằng test tự động

**Đây là việc quan trọng nhất của đợt này.** Không phải vì 4 pixel, mà vì hiện không có cách nào biết đã hết tràn ngoài mở máy ảo nhìn bằng mắt — và đó đúng là thứ cần bỏ.

### Vì sao bản vá hiện tại chưa đủ

Lần trước đã thử hai cách, cả hai đều không chạm nguyên nhân:

- Cắt 10px chiều cao (icon 24→20, các khoảng cách). Vẫn tràn 4px.
- Hạ nút xuống 42px khi `wearIsLarge(context) == false`, ngưỡng `shortestSide >= 225` — [`wear_widgets.dart:30`](lib/wear/wear_widgets.dart:30). **Đồng hồ trong ảnh là loại tròn 454px nên luôn rơi vào nhánh 48px, không được lợi một pixel nào.**

Nguyên nhân thật: `_alertView` là `Column` chiều cao cố định nằm trong `WearPage` không cuộn. Chiều cao thật phụ thuộc ba thứ mà code không kiểm soát — kích thước đồng hồ, **cỡ chữ hệ thống người dùng đặt**, và độ dài chuỗi tiếng Việt sau khi xuống dòng. Chỉnh số cho vừa một máy không bảo đảm gì cho máy khác.

### Việc cần làm

**Bước 1 — tách layout ra thành widget test được.**

`_alertView(_Trigger t)` trong [`wear_sensor_sos_screen.dart:356`](lib/wear/screens/wear_sensor_sos_screen.dart:356) hiện là method của State, nhưng **nội dung của nó thuần layout**: chỉ đọc `t`, `_countdown`, và hai callback. Không gọi mạng, không đọc provider.

Tách thành widget công khai, ví dụ `WearFallAlertView`, nhận vào:

```dart
class WearFallAlertView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String reading;      // rỗng thì không dựng dòng này
  final String question;
  final int countdown;
  final String dismissLabel;
  final VoidCallback onDismiss;
  final VoidCallback onSendNow;
}
```

Làm tương tự cho `_sentView` nếu tách được gọn. **Không đổi giao diện, không đổi hành vi** — chỉ di chuyển code.

**Bước 2 — sửa layout cho tự vừa.**

Trong widget vừa tách, bọc nội dung bằng mẫu "căn giữa khi vừa, cuộn khi không vừa":

```dart
LayoutBuilder(
  builder: (ctx, c) => SingleChildScrollView(
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: c.maxHeight),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [...]),
    ),
  ),
)
```

Vừa màn thì vẫn căn giữa y như bây giờ; dài hơn thì cuộn được thay vì tràn. Không mất nút nào.

⚠️ Ràng buộc riêng của màn này: **cả "Con ổn" lẫn "Gửi SOS" phải nằm sẵn trong tầm mắt ở cấu hình mặc định**, không được bắt cuộn mới thấy. Cuộn chỉ là lưới an toàn cho trường hợp cỡ chữ lớn bất thường. Nếu ở cỡ chữ mặc định mà vẫn phải cuộn thì rút gọn nội dung trước (gộp "Bạn có ổn không?" với dòng đếm ngược làm một), đừng chấp nhận cuộn như trạng thái bình thường.

**Bước 3 — test tự động chống tràn.** Đây là phần thay cho việc rà tay.

Flutter ném `FlutterError` khi `RenderFlex` tràn, và `tester.takeException()` bắt được. Tạo `test/wear_overflow_test.dart` với một helper dùng lại được:

```dart
Future<void> expectNoOverflow(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  ));
  expect(tester.takeException(), isNull,
      reason: 'tràn ở ${size.width}x${size.height}, textScale $textScale');
}
```

Chạy `WearFallAlertView` qua ma trận:

| Kích thước | Ý nghĩa |
|---|---|
| 384×384 | đồng hồ tròn nhỏ |
| 454×454 | đồng hồ tròn lớn — **đúng loại đang tràn trong ảnh** |
| 360×360 | đồng hồ vuông nhỏ |

× cỡ chữ `1.0`, `1.15`, `1.3` — cỡ chữ lớn là nguồn tràn phổ biến nhất và **chưa ai thử bao giờ**.

Test cả 3 giá trị `_Trigger` (té ngã không có dòng `reading`, hai case nhịp tim có) và vài giá trị `countdown` (20, 14, 1) vì độ rộng số đổi.

**Bước 4 — mở rộng dần, không hứa hết 15 màn.**

Đã kiểm: **10 trong 12 màn wear gọi mạng ngay trong `initState`** nên không dựng thẳng trong widget test được. Chỉ `wear_login_screen` và `wear_status_screen` là dựng được ngay.

Nên **đừng cố phủ hết 15 màn lượt này**. Làm đúng `WearFallAlertView` cho tốt, để helper `expectNoOverflow` ở dạng dùng lại được, rồi thêm màn khác khi có dịp tách layout. Repo đã có tiền lệ widget test (`test/register_screen_test.dart`, `test/calendar_member_widget_test.dart`) — đọc trước để theo cùng cách dựng.

### Kiểm chứng

Test phải **đỏ trước khi sửa layout** (chứng minh nó bắt được tràn thật), rồi xanh sau khi sửa. Nếu viết test xong mà nó xanh ngay từ đầu thì test đang không đo cái cần đo — dừng lại xem lại, đừng đi tiếp.

---

## A2. Khai đủ 9 `AiActionType`

### Bối cảnh

Dump OpenAPI mới khai `AiActionType` có **9 giá trị**. FE mới biết **4**:

```dart
// lib/models/ai_chatbot.dart:403
static const confirmedActionTypes = <String>{
  'CREATE_TASK', 'CREATE_LEDGER_ENTRY', 'CREATE_CALENDAR_EVENT', 'CREATE_BUDGET_PLAN',
};
```

Thiếu 5: `CREATE_BUDGET_LINE`, `CREATE_FINANCIAL_GOAL`, `CREATE_GOAL_ALLOCATION`, `CREATE_GOAL_CONTRIBUTION_PLAN`, `ALLOCATE_FUND_BY_MODEL`.

**Không vỡ** — Duy làm fail-open đúng: type lạ thì refresh toàn bộ và có sẵn `debugPrint` nhắc bổ sung ([`ai_assistant_screen.dart:1734`](lib/screens/shared/ai_assistant_screen.dart:1734)). Nhưng 5 loại này đang hiện icon/nhãn chung chung và refresh thừa.

### Việc cần làm

1. Thêm 5 chuỗi vào `confirmedActionTypes`.
2. Bổ sung nhánh cho `actionLabel`, `_actionIcon`, `_actionColor` trong `ai_assistant_screen.dart`. Cả 5 đều thuộc mảng tài chính nên dùng chung tông với `CREATE_BUDGET_PLAN`, khác icon:
   - `CREATE_BUDGET_LINE` → dòng ngân sách
   - `CREATE_FINANCIAL_GOAL` → mục tiêu
   - `CREATE_GOAL_ALLOCATION` / `CREATE_GOAL_CONTRIBUTION_PLAN` → đóng góp mục tiêu
   - `ALLOCATE_FUND_BY_MODEL` → chia quỹ theo hũ
3. Thêm cả 5 vào nhánh `refreshFinance` (hiện chỉ có `CREATE_BUDGET_PLAN`) — cả 5 đều ghi vào dữ liệu tài chính nên `FinanceProvider.fetchAll()` là đúng đích.
4. Thêm test khoá: mỗi `actionType` chính thức phải `isKnownActionType == true` và có nhãn **khác** chuỗi mặc định "Thực hiện đề xuất". Đặt trong `test/ai_pending_action_mapping_test.dart` cho gần các test cùng chủ đề.

### Ranh giới

**Chỉ thêm ánh xạ, không đụng logic confirm/reject.** Vùng đó Duy vừa ổn định xong và vẫn đang làm tiếp — sửa vào là vừa dễ conflict vừa dễ làm hỏng thứ đang chạy tốt.

---

## A3. Trạng thái vị trí trên đồng hồ và hiển thị nguồn vị trí

### A3.1 — Đồng hồ nói rõ đang ở trạng thái nào

Sau khi bỏ lùi về vị trí điện thoại, máy ảo Wear OS không set GPS là bản đồ trống — **đúng thiết kế nhưng nhìn y hệt lỗi**. Hiện chỉ có một dòng "Không lấy được vị trí đồng hồ" xuất hiện sau khi đã gửi xong.

Làm rõ thành ba trạng thái, hiện ngay trên màn SOS đồng hồ:

| Trạng thái | Khi nào | Chữ đề nghị |
|---|---|---|
| Đang lấy | `resolveSosPosition()` chưa trả về | "Đang lấy vị trí…" |
| Có vị trí | trả về toạ độ | "Đã có vị trí" |
| Không có | trả `null` | "Không lấy được GPS đồng hồ" |

Áp cho cả `wear_sos_screen` (SOS thủ công) và `wear_sensor_sos_screen` (cảm biến). Chỉ là chữ trạng thái, không chặn luồng gửi SOS.

### A3.2 — Bên nhận thấy vị trí đến từ đâu

`SosLocationPointResponseDto.sourceType` có `MOBILE_GPS | WEARABLE_GPS | SIMULATED_GPS` nhưng FE **chưa hiển thị ở đâu cả**. Người nhà nhìn bản đồ không biết chấm đó là điện thoại hay đồng hồ báo về — trong tình huống khẩn cấp đó là khác biệt có nghĩa.

Thêm nhãn nhỏ cạnh bản đồ trong sheet chi tiết SOS: "Vị trí từ đồng hồ" / "Vị trí từ điện thoại" / "Vị trí giả lập". Lấy `sourceType` của **điểm mới nhất** — chính là điểm mà `parseSosAlertLocation` đã chọn.

Muốn vậy thì `parseSosAlertLocation` phải trả thêm `sourceType`. Đổi kiểu trả về thành `({double lat, double lng, String? sourceType})` và cập nhật `test/sos_alert_location_test.dart` cho khớp. Test hiện có 5 case, thêm 1–2 case cho `sourceType`.

### A3.3 — Vẽ đường đi khi có nhiều điểm

Khi `locationPoints` có từ 2 điểm trở lên, vẽ `Polyline` nối các điểm theo `recordedAt` tăng dần, marker vẫn ở điểm mới nhất. `flutter_map` đã có sẵn `PolylineLayer`, không cần thêm thư viện.

Giá trị: thấy được người gặp nạn đang di chuyển theo hướng nào, không chỉ đứng ở đâu.

Chỉ vẽ khi **≥ 2 điểm hợp lệ**; 1 điểm thì giữ nguyên như hiện tại, không vẽ đường một chấm.

---

## A4. Cập nhật dump API và checklist wire

`family-care-api.json` trong repo **đang lỗi thời**: 226 path, thiếu hẳn `daily-brief`, `uiHints`, `ACTION_PLAN_CARD`, và hai endpoint confirm/reject theo `actionIndex`. Nghĩa là toàn bộ AI Sprint 2/3 được wire từ tin nhắn Discord, mất lớp đối chiếu mà Rule 1 dựng lên.

### Việc cần làm

1. **Export lại từ Swagger** — `https://api.familycare-digital.com/api/docs`. **Không dựng lại file từ đoạn dán trong chat**: file ~1 MB, dán hụt một khúc thì còn tệ hơn để cũ.
2. Sau khi thay file, **xác minh ngay** bằng cách parse và đếm — file phải parse được và số path phải tăng:
   ```
   python -c "import json;d=json.load(open('family-care-api.json',encoding='utf-8'));print(len(d['paths']),'paths',len(d['components']['schemas']),'schemas')"
   ```
3. Liệt kê endpoint mới so với bản 226 path, đối chiếu với `lib/` xem cái nào FE đã gọi, cái nào chưa.
4. Cập nhật `API_DOCS.md` theo Rule 1, kèm bảng **"FE đã wire / chưa wire"** để lần sau không phải dò lại từ đầu.

Không sửa code trong việc này. Nếu phát hiện mismatch FE-BE thì **ghi lại**, đừng tự sửa trong cùng lượt — tách ra để dễ đọc lịch sử.

---

# NHÓM B — Làm sau A, cần cẩn thận hơn

## B1. Đồng hồ gửi vị trí định kỳ khi SOS còn active

Hiện đồng hồ chỉ đẩy **một điểm** ngay sau khi cảnh báo tạo. Điện thoại thì đẩy mỗi 20 giây (`_startLocationStreaming`). Nghĩa là bản đồ từ đồng hồ là **một chấm tĩnh**, không chạy theo người đeo — đúng lúc cần theo dõi nhất thì lại không theo dõi được.

### Vì sao xếp nhóm B

Đụng vào luồng đang chạy trong tình huống khẩn cấp, và tốn pin đồng hồ. Làm sai thì hỏng đúng thứ quan trọng nhất.

### Ràng buộc bắt buộc

- Chu kỳ **thưa hơn điện thoại** — đề nghị 30 giây, không phải 20. Pin đồng hồ nhỏ hơn nhiều.
- **Dừng ngay** khi: người đeo bấm "Hủy báo động" (`confirm-safety` thành công), màn hình bị `dispose`, hoặc cảnh báo không còn `ACTIVE`.
- Đếm số lần lỗi liên tiếp, quá **3 lần** thì dừng hẳn và hiện trạng thái — giống cách đã làm cho poll activation ở `wear_pairing_screen`. Không lặp im lặng vô hạn.
- Mỗi lần đẩy vẫn dùng `WEARABLE_GPS` + `deviceId`.

Viết test cho phần đếm lỗi/điều kiện dừng nếu tách được ra hàm thuần. Nếu không tách được thì **ghi rõ trong PR là phần này chưa có test**, đừng để người sau tưởng đã phủ.

---

## B2. Tài liệu chuẩn bị demo

Thuần tài liệu, không đụng code, không rủi ro. Nhưng phải viết bằng thông tin **đã kiểm chứng trong repo**, không bịa.

Tạo `docs/DEMO_GUIDE.md` gồm:

- Cách ghép đồng hồ: đồng hồ hiện mã `FCW-XXXXXX` → nhập trên điện thoại ở **Hồ sơ → Thiết bị đeo**. Kèm cảnh báo migration: tài khoản đang PAIRED bằng mã cũ phải **xóa hẳn** bản ghi rồi ghép lại (bản ghi `UNPAIRED` vẫn giữ chỗ mã với thành viên khác).
- **Đặt GPS cho máy ảo Wear OS**: Extended controls → Location → chọn điểm → Set. Nêu rõ **bắt buộc** — không set thì bản đồ trống, và đó là hành vi đúng chứ không phải lỗi.
- Cách kích hoạt phát hiện té ngã: bật cảm biến thật, hoặc dùng 3 nút giả lập trên màn "Cảm biến SOS". Nhắc rằng **mỗi lần bấm là một cảnh báo thật gửi cho cả nhà** — BE không kiểm ngưỡng, cứ `HEART_RATE_ABNORMAL` là tạo SOS.
- Lệnh build: `flutter build apk --release`, và chạy app đồng hồ bằng `flutter run -d <emulator> --target lib/wear/main_wear.dart`.
- **Known issues** — lấy từ các mục còn treo trong `AI_HANDOFF_LATEST.md` và `CAU_HOI_BE_2026-08-07.md`, ghi trung thực. Đừng giấu.

---

## B3. Màn debug nội bộ

Giá trị thật: hiện tại muốn biết `familyId`, `deviceId` của wearable, hay alert nào đang ACTIVE thì phải đọc log. Có màn xem nhanh thì đỡ hẳn khi test.

### Ràng buộc bắt buộc

- Gate bằng `kDebugMode`, **không chỉ ẩn nút** mà phải để cả route không tồn tại ở release build.
- **Không hiện token đầy đủ.** Chỉ hiện 6 ký tự đầu + độ dài, ví dụ `eyJhbG… (312 ký tự)`. Token in ra màn hình rồi lọt vào ảnh chụp là rủi ro thật, kể cả ở debug.
- Chỉ **đọc**, không thêm nút thao tác gì. Đây là cửa sổ quan sát, không phải bảng điều khiển.

Nội dung: `userId` / `familyId` / `familyRole`, wearable đang ghép (`deviceId`, `pairingStatus`), SOS đang ACTIVE nếu có, và lỗi API gần nhất.

---

# PHẦN KHÔNG LÀM ĐỢT NÀY — và lý do

| Mục của Codex | Vì sao loại |
|---|---|
| Test thật SOS Wear OS → mobile → map | Cần thiết bị và thao tác tay. Đây là việc của anh, không giao được cho Codex. A1 làm phần thay thế được bằng máy. |
| Checklist test tay 15 màn Wear ở nhiều kích thước | Cùng lý do. A1 chuyển phần này thành test tự động cho màn đang hỏng. |
| Hồ sơ hiện "Đăng nhập bằng: Google / Mật khẩu" | **Chặn bởi BE.** `/auth/me` chưa trả `authProviders`. Đã có `DE_XUAT_BE_GOOGLE_LOGIN_LINK_2026-08-09.md` xin field này. Tự đoán là vi phạm Rule 2. |
| BE trả `linkedExistingAccount` | Việc của BE, đã gửi đề xuất, chỉ còn chờ. |
| Form chỉnh sửa trước khi xác nhận action AI | Đụng thẳng `ai_assistant_screen.dart` — vùng Duy vừa ổn định và vẫn đang làm. Rủi ro conflict cao và dễ làm hỏng thứ đang chạy tốt. Cần bàn với Duy trước, không tự làm. |
| Cảnh báo "Chưa gán hũ" trong thẻ đề xuất AI | Cùng file, cùng lý do như trên. |
| Chuẩn hóa lại `WearPage` / `WearPillButton` / `WearTile` | Refactor lan ra cả 15 màn nhưng **không có test nào phủ** — đúng định nghĩa mất ổn định. Làm A1 trước để có lưới an toàn, rồi mới tính. |
| Golden test | Ảnh golden trên Windows dễ lệch do khác font rendering, sẽ đỏ giả liên tục. Test bắt tràn ở A1 cho cùng giá trị mà không có nhược điểm đó. |

**Đề xuất BE về `categoryId` cho giao dịch AI tạo** — không loại hẳn, nhưng tách riêng: chỉ **soạn đề xuất**, không đụng UI thẻ AI. Nội dung: xin AI trả thêm `categoryId` khi suy luận được, hoặc `suggestedCategoryName` khi không chắc. Nhớ ghi đúng hiện trạng: giao dịch AI tạo **không** "mồ côi vĩnh viễn" như báo cáo trước đó — `WalletProvider.updateEntry` có gán `categoryId` và **đang được gọi** ở [`wallet_screen.dart:1363`](lib/screens/parent/wallet_screen.dart:1363), tức đã có màn sửa danh mục. Vấn đề chỉ là AI không gán sẵn nên mặc định rơi vào "Chưa gán hũ".

---

# Thứ tự và cách làm

| # | Việc | Vì sao xếp ở đây |
|---|---|---|
| 1 | A1 — tràn + test tự động | Đang hỏng thật, và mở đường an toàn cho mọi việc UI sau |
| 2 | A2 — 9 actionType | Nhỏ, gọn, không đụng ai |
| 3 | A3 — trạng thái GPS + nguồn + đường đi | Hoàn thiện phần SOS wearable vừa sửa |
| 4 | A4 — dump API | Dựng lại lớp đối chiếu trước khi wire thêm gì |
| 5 | B1 — gửi vị trí định kỳ | Cần A3 xong để nhìn thấy kết quả |
| 6 | B2, B3 | Không chặn ai, làm lúc nào cũng được |

## Ràng buộc chung

- Tài liệu, comment, commit message bằng **tiếng Việt**.
- **Rule 1** — đụng contract API thì cập nhật `API_DOCS.md` trong cùng thay đổi.
- **Rule 2** — BE thiếu gì thì dừng lại viết đề xuất, không mock/workaround.
- **Rule 3** — preview trước khi sửa: file nào, logic cũ → mới, rủi ro.
- Sau **mỗi** việc: `flutter analyze --no-fatal-infos` phải 0 error, `flutter test` phải xanh. Mốc hiện tại **309 test**; số test chỉ được tăng.
- Mỗi việc **một commit riêng**, đừng gộp. Nếu một file dính hai việc thì nói rõ trong message.
- Không commit `family-care-api.json` chung với thay đổi code.
