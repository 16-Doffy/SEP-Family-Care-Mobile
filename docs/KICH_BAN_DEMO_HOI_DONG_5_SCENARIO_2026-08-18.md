# Kịch bản Demo Trước Hội Đồng — 5 Scenario (Family Care, SU26SE032)

Ngày soạn: 2026-08-18 · Nhánh: `giap`.

Nguồn đối chiếu: `API_DOCS.md`, source code `lib/` tại thời điểm soạn (đọc trực tiếp, không suy
đoán tên nút/field), `docs/DEMO_GUIDE.md`, `docs/PHAN_TICH_DU_AN_VA_SCENARIO_GIA_DINH_2026-08-12.md`,
`AI_HANDOFF_LATEST.md`, và các báo cáo wearable/fall-detection 2026-08-16 → 2026-08-18
(`SO_SANH_TRUOC_SAU_WEARABLE_SOS_2026-08-16.md`, `BAO_CAO_BE_FALL_DETECTION_NATIVE_IMPLEMENTED_2026-08-18.md`,
`KE_HOACH_GARMIN_CONNECTIQ_INTEGRATION_2026-08-18.md`).

## 0. Cách dùng tài liệu này

Mỗi Scenario có cùng cấu trúc 7 mục: **Mục tiêu · Vai trò & thiết bị · Chuẩn bị dữ liệu · Kiến
trúc vận hành (để thuyết trình) · Các bước demo chi tiết · Kết quả mong đợi · Rủi ro & phương án
dự phòng**, kèm gợi ý câu hỏi hội đồng có thể hỏi.

Ký hiệu độ tin cậy đặt trước mỗi bước rủi ro:

- ✅ Đã verify runtime nhiều lần trên máy ảo/máy thật, ổn định — an toàn để demo trực tiếp.
- ⚠️ Đã code xong, `flutter analyze`/`flutter test` sạch, nhưng **CHƯA test trên thiết bị thật** hoặc còn bug đã biết — chỉ demo nếu đã tự tập dượt thành công trước.
- 🛑 Không nên demo trực tiếp ở trạng thái hiện tại — dùng phương án dự phòng (giải thích kiến trúc + ảnh/log chuẩn bị sẵn).

Tài liệu ưu tiên tính trung thực hơn tính hoành tráng: phần nào chưa chắc chắn được ghi rõ ngay
tại chỗ, đúng tinh thần các tài liệu `BAO_CAO_BE_*.md`/`DEMO_GUIDE.md` đã có sẵn trong repo — hội
đồng đánh giá cao việc nhóm tự biết rõ giới hạn của sản phẩm hơn là bị bắt bài lúc demo trực tiếp.

---

## 1. Tổng quan kiến trúc — mở đầu phần thuyết trình (~2 phút)

Nói trước khi bấm máy, không cần demo kèm:

- **Kiến trúc chung**: Flutter (Provider quản lý state + go_router điều hướng) ↔ một tầng
  `ApiClient` singleton duy nhất ↔ NestJS backend REST (`/api/v1`, mọi response bọc envelope
  `{success, data}`, FE tự bóc lớp này). Không có repository/DI layer — mỗi provider tự parse
  JSON thành model ngay trong file của nó.
- **3 kênh thời gian thực song song, dự phòng lẫn nhau**: Socket.IO (`/notifications`, `/chat`) khi
  app đang mở foreground; Firebase Cloud Messaging là kênh **duy nhất** hoạt động khi app ở nền/đã
  tắt; REST polling làm lưới an toàn cuối cùng cho chat.
- **AI Chatbot vận hành theo nguyên tắc "AI đề xuất, người xác nhận mới ghi"**: BE gọi LLM +
  tool-calling (tự tra cứu dữ liệu gia đình qua các tool nội bộ như `list_finance_categories`,
  `list_family_members`), sinh ra `pendingAction` kèm `preview`. **FE tuyệt đối không tự tạo dữ
  liệu từ `preview`** — chỉ hiển thị để đối chiếu, chờ người dùng bấm Xác nhận mới gọi API ghi
  thật. Đây là câu trả lời chuẩn khi hội đồng hỏi "AI có tự ý thao túng dữ liệu gia đình không?".
- **SOS tách rời "tạo cảnh báo" và "định vị GPS" thành 2 API độc lập**: cảnh báo được tạo ngay lập
  tức không chờ GPS (tránh chậm trễ trong tình huống khẩn cấp thật), toạ độ được đẩy lên sau theo
  kiểu best-effort, cập nhật định kỳ 30 giây trong lúc alert còn `ACTIVE`.
- **Wearable có 2 kiến trúc song song, độc lập nhau**: (a) **Wear OS** — một app Flutter thứ hai
  (`lib/wear/`) chạy thẳng trên đồng hồ/máy ảo Wear OS, dùng chung cây provider với app điện thoại,
  tự gọi thẳng API; (b) **Garmin thật** — đồng hồ chạy watch app viết bằng Monkey C (ngoài phạm vi
  repo Flutter, do nhóm khác phụ trách), điện thoại Android đóng vai trò **cầu nối (bridge) duy
  nhất** qua Garmin Connect IQ Mobile SDK, tự nhận sự kiện cảm biến rồi POST hộ lên backend bằng
  chính JWT của người dùng.
- **Face Recognition chạy bất đồng bộ, không có bước nào tự động tạo tag**: BE xử lý nhận diện
  khuôn mặt ngoài luồng chính (FE tự poll trạng thái tối đa ~12 giây), mọi gợi ý — dù độ tin cậy
  cao tới đâu — đều cần người dùng bấm Xác nhận mới trở thành tag chính thức. Đây là quyết định
  nghiệp vụ đã chốt, không phải giới hạn kỹ thuật.

---

## 2. Chuẩn bị trước buổi demo — checklist bắt buộc

**An toàn mã nguồn (quan trọng nhất, dễ bỏ sót nhất):**

- ⚠️ Working tree hiện có **diff CHƯA COMMIT** ở `AndroidManifest.xml`,
  `GarminBridgeService.kt`, `MainActivity.kt` — diff này sửa một **lỗi crash thật** (app crash khi
  mở với user chưa từng cấp quyền Bluetooth, do `foregroundServiceType="connectedDevice"` đòi
  runtime permission). **Tuyệt đối không `git checkout`/`git reset --hard`/build từ commit sạch**
  trước ngày bảo vệ — sẽ build lại đúng bản có bug crash. Nên commit diff này sớm, không để treo.
- Build APK demo **từ đúng working tree hiện tại** (có diff trên), không dùng APK build từ trước
  ngày 18/08.

**Tài khoản & dữ liệu mồi:**

| Hạng mục | Chuẩn bị |
|---|---|
| 3 tài khoản demo | 1 Manager (Bố), 1 Deputy (Mẹ — cấp quyền trong Scenario 1), 1 Member (Con) |
| Gói subscription | Family demo phải ở gói có bật `ai.assistant` (Trợ lý AI) — kiểm tra trước ở màn Gói đăng ký, đừng để bị chặn giữa buổi demo |
| Mô hình tài chính | Tạo + **kích hoạt (activate)** sẵn 1 model (khuyến nghị 5 Hũ) trước ngày bảo vệ — AI **không tự tạo/activate model được**, đã xác nhận runtime 2026-08-10 |
| Khoản thu trong kỳ | Ghi sẵn ít nhất 1 khoản thu cho kỳ sẽ dùng để demo "chia quỹ", tránh lỗi thiếu quỹ khả dụng |
| Face Profile | Enroll sẵn Face Profile cho ít nhất 2 thành viên **trước** ngày bảo vệ (chuẩn bị sẵn 3-5 ảnh rõ mặt, 1 mặt/ảnh cho mỗi người — ảnh mờ/nhiều mặt/ảnh > vài MB sẽ bị BE từ chối lúc validate) |
| Ảnh album | Upload sẵn vài ảnh gia đình **từ trước**, chờ AI kiểm duyệt xong (chuyển `SAFE`) — không demo quét khuôn mặt ngay trên ảnh vừa upload trong lúc demo |
| Wearable | Pair sẵn 1 Wear OS emulator/thiết bị cho tài khoản Con, đặt GPS (Extended controls → Location) trước khi vào phòng bảo vệ |

**Thông báo cho cả nhóm:** SOS cảm biến (kể cả nút "Giả lập") tạo **cảnh báo thật**, gửi thông báo
thật tới mọi thành viên gia đình demo — báo trước cho người cầm điện thoại người nhận để không giật
mình giữa buổi.

---

## 3. Scenario 1 — Family Onboarding & Role Management

### Mục tiêu
Chứng minh vòng đời "1 gia đình từ 0 tới đủ 3 vai trò" và 2 trục phân quyền độc lập
(`familyRole` vs `userType`) hoạt động đúng — không dùng chung 1 cờ "quản trị" cho mọi hành động
nhạy cảm.

### Vai trò & thiết bị
Bố (điện thoại A) tạo gia đình. Mẹ (điện thoại B) xin gia nhập rồi được cấp Phó nhóm.

### Chuẩn bị dữ liệu
Không cần dữ liệu mồi — đây là scenario duy nhất nên chạy **thật** từ tài khoản trắng để tính
thuyết phục cao nhất (không phải dữ liệu dựng sẵn).

### Kiến trúc vận hành (nói khi demo tới bước tương ứng)
- Family Care dùng **mã mời tái sử dụng 8 ký tự + QR** (không phải link email dùng 1 lần) —
  Trưởng nhóm tạo 1 mã, chia sẻ cho ai cũng được, người nhận **luôn phải qua bước Trưởng nhóm duyệt
  tay** mới thực sự vào gia đình (`claim → approve`, không có `auto-accept`).
- Vai trò (`familyRole`: Manager/Deputy/Member) và quan hệ gia đình (`relationship`: Bố/Mẹ/Con...)
  là **2 field độc lập** — chọn sai lúc duyệt không kẹt vĩnh viễn, Trưởng nhóm sửa lại được sau,
  nhưng có ràng buộc nghiệp vụ: mỗi gia đình chỉ được đúng **1 Bố** và **1 Mẹ** đang hoạt động.

### Các bước demo chi tiết

| # | Ai làm | Thao tác | Màn hình / API đứng sau |
|---|---|---|---|
| 1 | Bố | Đăng ký tài khoản mới (email, mật khẩu ≥8 ký tự có hoa/thường/số/ký tự đặc biệt) | `register_screen.dart` → `POST /auth/register` |
| 2 | Bố | Nhập OTP 6 số xác thực email nếu app yêu cầu | `verify_email_screen.dart` |
| 3 | Bố | Màn "Thiết lập gia đình" → nhập **Tên gia đình** → bấm **"Tạo gia đình"** | `family_setup_screen.dart` → `POST /families` |
| 4 | Bố | Vào **Mã mời gia đình** (icon nhóm ➕ trong màn Thành viên) → bấm **"Tạo mã mời"** → xem mã 8 ký tự + QR | `invite_member_screen.dart` → `GET/POST /families/{id}/invite-code(/regenerate)` |
| 5 | Mẹ | Đăng ký/đăng nhập tài khoản riêng → màn "Thiết lập gia đình" → bấm **"Tham gia bằng mã mời"** → nhập mã 8 ký tự (hoặc quét QR) | `join_family_screen.dart` → preview tên gia đình trước khi gửi |
| 6 | Mẹ | Xem preview đúng tên gia đình "..." → bấm gửi yêu cầu (có thể kèm lời nhắn) | `POST /invite-codes/{code}/join-requests` — màn tự chuyển sang poll trạng thái mỗi 12s |
| 7 | Bố | Vào **"Yêu cầu tham gia"** → thấy yêu cầu của Mẹ → chọn **Vai trò = Thành viên**, **Mối quan hệ = Mẹ** → bấm **"Duyệt yêu cầu"** | `invitation_requests_screen.dart` → `POST /join-requests/{id}/approve` |
| 8 | Mẹ | Màn tự động điều hướng sang Trang chủ ngay khi poll thấy `APPROVED` (không cần thao tác gì thêm) | `AuthProvider.refreshFamilyContext()` |
| 9 | Bố | Vào Thành viên → chọn Mẹ → màn Chi tiết thành viên → bấm **"Bổ nhiệm Phó nhóm"** → xác nhận | `member_detail_screen.dart` → `PATCH /members/{userId}/role` (`grantDeputy`) |
| 10 | Bố *(tuỳ chọn nếu cần sửa quan hệ)* | Trong cùng màn Chi tiết thành viên, bấm **"Đổi quan hệ"** nếu lúc duyệt chọn nhầm | `PATCH /members/{userId}/relationship` |

### Kết quả mong đợi
- Gia đình có 2 thành viên hoạt động: Bố = Trưởng nhóm, Mẹ = Phó nhóm.
- Mẹ tự thấy giao diện đổi từ Member sang Deputy ngay sau khi được bổ nhiệm (không cần đăng nhập lại).

### Rủi ro & phương án dự phòng
- ✅ Toàn bộ luồng này là luồng lõi, dùng hằng ngày trong quá trình phát triển — rủi ro thấp nhất
  trong 5 scenario.
- Nếu Mẹ nhập sai email lúc đăng ký so với dự tính không sao — luồng mã mời **không yêu cầu email
  trùng khớp** như luồng link mời cũ, chỉ cần đúng mã 8 ký tự.
- Nếu bấm nhầm "Bổ nhiệm Phó nhóm" cho đúng người nhưng muốn thu hồi: cùng nút đó đổi thành "Gỡ
  quyền Phó nhóm" khi đang là Deputy.

### Câu hỏi hội đồng có thể hỏi
- *"Vì sao không duyệt tự động, phải qua 2 bước claim → approve?"* → Chống người lạ tự ý gia nhập
  chỉ bằng cách đoán/lộ mã mời; Trưởng nhóm luôn là người quyết định cuối cùng ai vào nhà.
- *"Phó nhóm có quyền gì khác Thành viên?"* → Quản lý nhiệm vụ/tài chính/lịch, duyệt yêu cầu hỗ trợ
  chi tiêu, xử lý SOS — nhưng **không** mời thành viên mới, không cấp/thu quyền Phó nhóm khác,
  không xoá thành viên, không quản lý gói subscription (4 quyền này chỉ Trưởng nhóm).

---

## 4. Scenario 2 — AI-assisted Task & Calendar Coordination

### Mục tiêu
Chứng minh AI có thể **hiểu ngôn ngữ tự nhiên tiếng Việt và đề xuất hành động thật** (giao việc,
tạo lịch), nhưng **luôn dừng lại chờ người có thẩm quyền xác nhận** trước khi ghi dữ liệu, và dữ
liệu sau khi tạo đi đúng vòng đời thông báo → thực hiện → phản hồi.

### Vai trò & thiết bị
Bố (Manager) ra lệnh cho AI. Con (Member) nhận việc/lịch trên điện thoại.

### Chuẩn bị dữ liệu
Không bắt buộc, nhưng nên có sẵn 1-2 nhiệm vụ/sự kiện cũ trong danh sách để câu hỏi tra cứu
("Tôi còn nhiệm vụ nào chưa hoàn thành?") có dữ liệu trả lời phong phú hơn.

### Kiến trúc vận hành
- Một tin nhắn AI có thể sinh **nhiều đề xuất cùng lúc** (`pendingActions[]`, gọi là
  `ACTION_PLAN_CARD`) — ví dụ 1 câu vừa tạo lịch vừa ghi khoản chi ra đúng 1 tin nhắn chứa 2 thẻ
  xếp chồng, xác nhận/từ chối **độc lập từng thẻ**.
- Có đúng **9 loại đề xuất** AI được phép sinh (`actionType`); phần liên quan Task/Calendar là
  `CREATE_TASK` và `CREATE_CALENDAR_EVENT`. Đề xuất có `expiresAt` (ISO UTC) — hết hạn phải chat
  lại để AI tạo đề xuất mới, không có API "gia hạn".
- Sau khi Xác nhận, hệ thống thông báo tới đúng người được giao qua `NotificationType.TASK`/
  `CALENDAR`, đẩy cả 3 kênh (Socket.IO nếu đang mở app, FCM nếu app nền, badge số chưa đọc).

### Các bước demo chi tiết

**Nhánh A — Giao nhiệm vụ qua AI**

| # | Ai làm | Thao tác |
|---|---|---|
| 1 | Bố | Mở **Trợ lý AI** → gõ (hoặc bấm chip gợi ý) một câu **trọn vẹn trong 1 lượt**: *"Tạo nhiệm vụ dọn bàn học lúc 19h tối nay, giao cho Con"* |
| 2 | Bố | AI trả lời + hiện thẻ đề xuất **"Tạo nhiệm vụ"** với preview: nội dung việc, người nhận (đã hiện đúng **tên**, không phải UUID thô), hạn hoàn thành |
| 3 | Bố | Đọc lại preview, bấm **"Xác nhận"** | 
| 4 | Bố | Banner đổi màu xanh, nội dung đúng "đã tạo nhiệm vụ" |
| 5 | Con | Nhận thông báo đẩy (hoặc mở app thấy badge đỏ) → mở **Nhiệm vụ** → thấy việc mới |
| 6 | Con | Mở chi tiết → bấm **"Bắt đầu làm ▶️"** |
| 7 | Con | Hoàn thành → bấm **"Nộp nhiệm vụ"** (kèm ảnh minh chứng nếu task yêu cầu) |
| 8 | Bố/Mẹ | Vào Quản lý nhiệm vụ → mở bài nộp mới nhất → duyệt (Approve) |

**Nhánh B — Tạo lịch gia đình qua AI**

| # | Ai làm | Thao tác |
|---|---|---|
| 9 | Bố | Vẫn trong Trợ lý AI: *"Tạo lịch khám sức khỏe 9h sáng mai tại phòng khám gần nhà, mời cả nhà"* — **tránh dùng cụm tương đối kiểu "cuối tuần này" trong câu cần AI hỏi lại thêm chi tiết**, xem cảnh báo bên dưới |
| 10 | Bố | Thẻ đề xuất **"Tạo lịch"** hiện preview ngày giờ dạng người đọc được (không phải chuỗi ISO thô) → **Xác nhận** |
| 11 | Cả nhà | Mở **Lịch** → sự kiện xuất hiện đúng ngày → mỗi người bấm 1 trong 3 lựa chọn phản hồi: **"Tham gia" / "Có thể" / "Từ chối"** |

### Kết quả mong đợi
- Nhiệm vụ/sự kiện AI tạo xuất hiện y hệt như tạo tay ở đúng màn quản lý tương ứng.
- Người được giao nhận thông báo mà không cần tự mở app dò tìm.
- Vòng đời Nhiệm vụ đi đúng trạng thái `ASSIGNED → IN_PROGRESS → SUBMITTED → APPROVED`.

### Rủi ro & phương án dự phòng
- ✅ `CREATE_TASK`/`CREATE_CALENDAR_EVENT` đơn lẻ, gộp đủ thông tin trong 1 câu: đã verify runtime
  ổn định nhiều lần.
- ⚠️ **Tránh kịch bản "AI hỏi lại rồi mới trả lời"** (ví dụ gõ "tạo lịch cuối tuần" không kèm chi
  tiết, để AI hỏi giờ/địa điểm rồi trả lời ở tin tiếp theo) — đã ghi nhận bug ngày sinh ra lệch (ra
  thứ Năm thay vì thứ Bảy/Chủ Nhật) trong đúng luồng 2 lượt này. **Luôn gộp đủ thông tin (việc/giờ/
  người nhận/địa điểm) trong đúng 1 câu khi demo trực tiếp** để né hoàn toàn lỗi này.
- Nếu AI trả lời bằng chữ suông, không kèm thẻ đề xuất nào: gửi lại đúng câu đó 1 lần — đây là lỗi
  chập chờn hiếm gặp đã từng ghi nhận, không phải luôn luôn xảy ra.

### Câu hỏi hội đồng có thể hỏi
- *"Nếu AI hiểu sai giờ/ngày thì sao?"* → Người dùng luôn thấy `preview` trước khi xác nhận — nếu
  sai, bấm **"Sửa"** để từ chối đề xuất hiện tại và gõ lại câu rõ ràng hơn (AI không có form sửa
  trực tiếp, đây là hành vi đã chốt thiết kế, không phải thiếu sót).
- *"AI có được tự giao việc không cần ai duyệt không?"* → Không — `CREATE_TASK` cũng đi qua đúng
  vòng đời `pendingAction` như mọi actionType khác, luôn cần người có quyền bấm Xác nhận.

---

## 5. Scenario 3 — AI-assisted Finance Management

### Mục tiêu
Chứng minh hệ thống tài chính gia đình có cấu trúc thật (mô hình hũ, ngân sách, mục tiêu) chứ
không chỉ là sổ thu chi đơn thuần, và AI có thể thao tác trên đúng cấu trúc đó khi được xác nhận.

### Vai trò & thiết bị
Bố/Mẹ (Manager/Deputy) là 2 vai trò duy nhất được ghi vào sổ chung. Con (Member) chỉ khai báo tài
chính cá nhân, không ghi được sổ chung — **nên nói rõ điểm này khi demo** vì đây là ranh giới quyền
hay bị hỏi.

### Chuẩn bị dữ liệu — bắt buộc làm trước, KHÔNG demo AI tạo mô hình tài chính live
Đã xác nhận runtime (2026-08-10): AI có thể **giải thích** mô hình 80/20 bằng lời, nhưng **không
tự tạo/kích hoạt mô hình thật**. Nếu gia đình demo chưa có mô hình `ACTIVE`, mọi đề xuất "chia quỹ"
của AI sẽ bị khoá nút xác nhận. Vì vậy:
1. Trước ngày bảo vệ: vào **Mô hình tài chính** → tạo mô hình **5 Hũ** → **Kích hoạt**.
2. Ghi sẵn ít nhất 1 khoản thu vào đúng kỳ (tháng) sẽ dùng để demo chia quỹ.

### Kiến trúc vận hành
- Tiền vào sổ chung có `entryType` (`INCOME | EXPENSE | CONTRIBUTION | ALLOWANCE | REWARD |
  SUPPORT | ADJUSTMENT`) quyết định dấu +/- , không suy từ số tiền (BE luôn trả số dương).
- Khi ghi giao dịch, FE chỉ gửi **`categoryId`**, không gửi `jarId` — BE tự tra bảng ánh xạ
  category → hũ của **mô hình đang ACTIVE** để gán đúng hũ, giữ đúng nguyên tắc "chọn danh mục,
  hệ thống tự lo phần hũ".
- 9 loại đề xuất AI, phần Finance chiếm 7/9: `CREATE_LEDGER_ENTRY`, `CREATE_BUDGET_PLAN`,
  `CREATE_BUDGET_LINE`, `CREATE_FINANCIAL_GOAL`, `CREATE_GOAL_ALLOCATION`,
  `CREATE_GOAL_CONTRIBUTION_PLAN`, `ALLOCATE_FUND_BY_MODEL`.
- Báo cáo/cảnh báo được **tính sẵn trên server** (`reports/jar-target-actual`,
  `reports/overview`, `finance/alerts`) — FE không tự cộng dồn ở client để tránh sai lệch logic.

### Các bước demo chi tiết

| # | Ai làm | Thao tác |
|---|---|---|
| 1 | Con | Vào **Ví cá nhân** → khai báo Tài chính tháng (thu nhập/chi tiêu dự kiến cá nhân) — minh hoạ Member **không** đụng vào sổ chung |
| 2 | Bố | Vào **Sổ thu chi** → ghi tay 1 khoản chi mẫu (vd 200.000đ tiền ăn) để có dữ liệu nền |
| 3 | Bố/Mẹ | Vào **Ngân sách** → xem mô hình 5 Hũ đã kích hoạt sẵn; hoặc tạo **"Tạo kế hoạch ngân sách"** tháng này nếu chưa có |
| 4 | Bố | Mở **Trợ lý AI**, hỏi thuần tuý (không tạo dữ liệu): *"Tháng này nhà mình đã chi bao nhiêu?"*, *"Hũ nào đang chi vượt mục tiêu?"* → AI trả lời bằng chữ, có định dạng đậm/markdown, **không** kèm thẻ xác nhận (đây là câu hỏi tra cứu, không phải hành động ghi) |
| 5 | Bố | Yêu cầu AI hành động: *"Tạo mục tiêu tiết kiệm 20.000.000đ để mua xe máy, hạn tháng 12 năm nay"* → thẻ **`CREATE_FINANCIAL_GOAL`** hiện preview → **Xác nhận** |
| 6 | Bố | Yêu cầu tiếp: *"Thêm dòng ngân sách 2.000.000đ cho mục ăn uống"* → thẻ **`CREATE_BUDGET_LINE`** → **Xác nhận** |
| 7 | Bố *(nâng cao, chỉ demo nếu đã tập dượt trước — xem Rủi ro)* | *"Chia quỹ tháng [kỳ đã chuẩn bị] theo mô hình tài chính đang áp dụng với tổng tiền 100.000đ"* → thẻ **`ALLOCATE_FUND_BY_MODEL`** → **Xác nhận** |
| 8 | Bố/Mẹ | Vào **Báo cáo tài chính** → tab "Ngân sách & Mục tiêu", tab "Theo hũ" → chỉ số cập nhật đúng theo dữ liệu vừa tạo |
| 9 | Bố/Mẹ | Vào **Cảnh báo tài chính** → nếu có mục chi vượt ngân sách, minh hoạ 1 cảnh báo `OVER_BUDGET`/`GOAL_AT_RISK` |

### Kết quả mong đợi
- Mục tiêu/ngân sách AI tạo xuất hiện đúng ở màn quản lý tương ứng, số liệu khớp với những gì AI
  đã preview trước khi xác nhận.
- Báo cáo "Theo hũ" phản ánh đúng tỷ lệ % mục tiêu so với thực chi.

### Rủi ro & phương án dự phòng
- ✅ `CREATE_BUDGET_LINE` và `CREATE_FINANCIAL_GOAL`: đã verify runtime ổn định nhiều lần, ưu tiên
  chọn 2 loại này làm phần "chắc ăn" của scenario.
- ⚠️ `ALLOCATE_FUND_BY_MODEL` rủi ro cao hơn: từng có lỗi 502 lúc xác nhận và lỗi thiếu quỹ khả
  dụng theo kỳ tương lai — bản chốt gần nhất từ BE (08-10) báo đã sửa nhưng **cần tự tập dượt lại
  ít nhất 1 lần trước ngày bảo vệ** với đúng kỳ đã chuẩn bị sẵn khoản thu. Nếu chưa tập dượt được,
  bỏ bước 7, thay bằng giải thích bằng lời + ảnh chụp màn hình đã chạy thành công trước đó.
  **Chỉ demo chia quỹ cho 1 kỳ CHƯA từng chia trước đó** — mỗi kỳ chỉ được chia đúng 1 lần
  (`409 FUND_ALLOCATION_ALREADY_EXISTS` nếu lặp lại), đây là rule nghiệp vụ đúng, không phải bug.
- Giao dịch AI tạo có thể chưa có `categoryId` (AI chỉ gán khi khớp rõ nghĩa) → rơi vào "Chưa phân
  loại" ở báo cáo theo hũ — nếu gặp, giải thích đây là hành vi đã biết, người dùng chọn lại danh
  mục thủ công trong Sổ thu chi.

### Câu hỏi hội đồng có thể hỏi
- *"Vì sao Member không ghi được sổ chung?"* → Tránh 1 thành viên tự ý ghi thu/chi ảnh hưởng quỹ cả
  nhà mà không ai kiểm soát; Member chỉ khai báo tài chính cá nhân, muốn chi từ quỹ chung phải gửi
  **yêu cầu hỗ trợ chi tiêu** để Manager/Deputy duyệt (có thể trình diễn nhanh nếu hội đồng hỏi
  sâu, không nằm trong 5 scenario chính).
- *"AI có tính sai được không, ai chịu trách nhiệm?"* → Mọi phép tính báo cáo chạy trên server, FE
  chỉ hiển thị; AI chỉ đề xuất **cấu trúc** giao dịch (số tiền, mục tiêu), số liệu tổng hợp cuối
  cùng luôn do BE tính, không qua AI.

---

## 6. Scenario 4 — SOS & Wearable Emergency Response

### Mục tiêu
Chứng minh hệ thống phản ứng khẩn cấp có **nhiều lớp kích hoạt độc lập** (tay bấm, cảm biến điện
thoại, cảm biến đồng hồ) hội tụ về cùng 1 luồng xử lý, và gia đình nhận – phản hồi được ngay.

### ⚠️ Cập nhật 2026-08-19: UI đã đổi so với bản viết kịch bản gốc 18/08 — đọc trước khi thuyết trình
Bản kịch bản gốc (18/08) viết theo UI cũ: bấm nút giả lập → đếm ngược 20s → gửi thẳng, không kiểm tra
điều kiện, không hiển thị gì trước đó. Ngày 19/08, sau khi BE xác nhận **chỉ triển khai phần UI/gate
("Track A"), chưa làm lại detector thật ("Track B", chính thức hoãn sau mùa bảo vệ)**,
`wear_sensor_sos_screen.dart` đã đổi thật so với bản 18/08 — 3 điểm cần biết trước khi lên slide/demo:

1. **Preflight gate**: nút giả lập tự khoá (kèm lý do cụ thể) nếu gia đình chưa bật SOS, wearable
   chưa bật SOS, hoặc (riêng té ngã) chưa bật tự tạo cảnh báo té ngã — không còn tình trạng bấm xong
   đợi 20s mới biết không có gì xảy ra.
2. **Hiệu ứng biến động trên UI**: bấm nút → subtitle của tile chạy qua một chuỗi số liệu mô phỏng
   (~2 giây, vd té ngã `1.0g → 0.9g → 0.3g → 0.1g → 0.2g → 1.8g → 3.2g → 1.0g`, nhịp tim cao
   `78 → 92 → 110 → 126 → 136 → 142 bpm`) rồi mới mở đếm ngược 20s. **Đây là hiệu ứng hình ảnh minh
   hoạ, không phải kết quả đo hay thuật toán phát hiện thật** — nói thẳng điều này nếu hội đồng hỏi
   sâu, giá trị cuối chuỗi luôn khớp đúng payload gửi BE như trước, không có `HeartRateDetector`/
   `FallDetector` thật tham gia quyết định (2 file đó vẫn mồ côi, chưa được import ở đâu khác), không
   có snooze.
3. **Dòng mô tả mới** dưới "Giả lập (demo)": *"Gửi một sự kiện cảm biến lên máy chủ — máy chủ tự
   quyết định có tạo cảnh báo hay không, khác với nút SOS thủ công."* — nên đọc nguyên câu này khi
   trình bày, đây chính là câu trả lời cho câu hỏi "tại sao nút giả lập lại tạo SOS thật".

Nhãn nút vẫn giữ nguyên "Giả lập té ngã/nhịp tim cao/nhịp tim thấp" — **không** đổi thành "Chạy tín
hiệu..." như 2 báo cáo 16-17/08 từng mô tả (đó là phần Track B, vẫn chưa làm). Chi tiết đầy đủ + gợi ý
code nên show cho hội đồng ở `PHAN_TICH_SOS_WEARABLE_FALL_HEART_RATE_2026-08-19.md`. Trước ngày bảo vệ
vẫn nên tự chạy lại `flutter run --target lib/wear/main_wear.dart` để xác nhận UI thật một lần nữa.

### Vai trò & thiết bị
Con đeo Wear OS (emulator hoặc thiết bị) + điện thoại thật. Bố/Mẹ dùng điện thoại nhận cảnh báo.

### Chuẩn bị dữ liệu
- Wear OS emulator: đặt GPS trước qua Extended controls → Location.
- Con đã ghép wearable từ điện thoại (mã `FCW-XXXXXX`) — xem bước 1.
- Điện thoại Con: bật sẵn "Bảo vệ SOS trên máy này" (lắc mạnh / theo dõi té ngã nền) trong Cài đặt
  SOS nếu định demo nhánh lắc điện thoại.

### Kiến trúc vận hành
- Wear OS **không gọi thẳng `/sos/alerts`** cho 2 case tự động (té ngã/nhịp tim) — gọi
  `POST /wearables/{deviceId}/events`, để BE tự quyết định có tạo cảnh báo hay không và **tự chống
  trùng** nếu người đeo đang có SOS `ACTIVE`. Gọi thẳng `/sos/alerts` sẽ mất cả 2 cơ chế này.
  SOS tay bấm và SOS từ điện thoại vẫn đi thẳng `/sos/alerts` như bình thường.
  - Bấm giữ nút SOS trên đồng hồ = tạo cảnh báo ngay lập tức, không đếm ngược.
  - Cảm biến (té ngã/nhịp tim) = màn cảnh báo đếm ngược **20 giây**, có nút huỷ (**"Con ổn"**/
    **"Đã ổn"**) hoặc gửi ngay (**"Gửi SOS"**).
- SOS từ cảm biến ban đầu không có toạ độ (payload sự kiện không mang vị trí) — sau khi có
  `alertId`, đồng hồ mới hỏi GPS của chính nó rồi đẩy bù 1 điểm, để không làm chậm việc tạo cảnh
  báo. Vị trí sau đó lặp lại mỗi 30 giây cho tới khi alert hết `ACTIVE`.
- 2 kiến trúc "đồng hồ" độc lập nhau (nhắc lại từ mục 1): Wear OS là app Flutter thật; Garmin thật
  là bridge qua Connect IQ SDK — **không dùng chung code, không thay thế nhau được**.

### Các bước demo chi tiết

**Bước 1 — Ghép thiết bị đeo** ✅
| # | Ai làm | Thao tác |
|---|---|---|
| 1 | Con | Mở app Wear OS trên emulator → màn hiện mã `FCW-XXXXXX` |
| 2 | Con (điện thoại) | Vào **Hồ sơ → Thiết bị đeo** → nhập mã → chờ đồng hồ tự chuyển trạng thái `PAIRED` |

*(Nói thêm, không demo live: kiến trúc còn hỗ trợ ghép đồng hồ **Garmin thật** qua nút "Ghép đồng
hồ Garmin" cùng màn — xem mục Rủi ro, phần này **chưa** nên demo trực tiếp.)*

**Bước 2 — Kích hoạt SOS: chọn 1 hoặc 2 trong 3 nhánh sau tuỳ mức độ tự tin**

| Nhánh | Thao tác | Độ tin cậy |
|---|---|---|
| A. Tay bấm trên đồng hồ | Vào **SOS** trên Wear OS → giữ nút SOS 2 giây | ✅ ổn định nhất, nên chọn làm nhánh chính |
| B. Cảm biến giả lập trên đồng hồ | Vào **Cảm biến SOS** → bấm 1 trong 3 ô **"Giả lập té ngã"/"Giả lập nhịp tim cao"/"Giả lập nhịp tim thấp"** → xem màn đếm ngược 20s → bấm **"Gửi SOS"** để không phải chờ hết giờ | ✅ đúng UI thật, đã verify — nhưng **tạo cảnh báo thật**, nhớ báo trước người nhận |
| C. Lắc điện thoại lúc khoá màn hình | Khoá màn hình điện thoại Con vài giây → lắc mạnh | ✅ đã test PASS trên máy Oppo thật 2026-08-12 — ấn tượng nhất vì màn SOS tự bung đè lên màn khoá |

*Không chọn nhánh D (té ngã nền/khoá máy qua service native mới `SosEmergencyFlowService`) và
nhánh E (Garmin thật) làm demo chính — xem Rủi ro.*

**Bước 3 — Gia đình nhận và xử lý** ✅
| # | Ai làm | Thao tác |
|---|---|---|
| 3 | Bố/Mẹ | Nhận thông báo đẩy mức ưu tiên cao (banner đỏ toàn cục) → mở chi tiết SOS |
| 4 | Bố/Mẹ | Xem người gửi, mức độ nghiêm trọng, **bản đồ vị trí** (chờ vài giây nếu vừa mở quá sớm — có nút tải lại) |
| 5 | Bố/Mẹ | Bấm phản hồi **"Tôi đang đến"**/xác nhận đã xem |
| 6 | Con hoặc Bố/Mẹ | Tình huống đã an toàn: Con bấm **"Hủy báo động"** trên đồng hồ (tự xác nhận an toàn), hoặc Bố/Mẹ **Resolve** kèm ghi chú từ điện thoại |

### Kết quả mong đợi
- Cảnh báo được tạo gần như tức thời, không chờ có GPS mới tạo được.
- Gia đình nhận thông báo đúng mức ưu tiên cao, xem được bản đồ sau vài giây.
- Alert đóng đúng khi có xác nhận an toàn hoặc resolve, dừng gửi vị trí định kỳ.

### Rủi ro & phương án dự phòng (đọc kỹ mục này trước khi chốt kịch bản cuối)

| Cách kích hoạt | Trạng thái | Khuyến nghị |
|---|---|---|
| Tay bấm (đồng hồ/điện thoại/home shortcut) | ✅ ổn định lâu dài | Dùng làm nhánh chính, an toàn nhất |
| Lắc điện thoại (khoá/mở màn) | ✅ test PASS máy thật 12/08 | Dùng làm nhánh "ấn tượng thị giác" |
| Cảm biến giả lập trên Wear OS | ✅ đúng UI thật đã verify | Dùng được, nhớ cảnh báo trước vì tạo SOS thật |
| Té ngã điện thoại lúc app đang mở (foreground) | ✅ đường cũ, ổn định | Có thể demo phụ nếu còn thời gian |
| Té ngã điện thoại lúc nền/khoá máy (`SosEmergencyFlowService` mới, 18/08) | 🛑 **chưa test trên thiết bị thật** — tự ghi rõ trong báo cáo BE | Không demo live trừ khi đã tự tập dượt thành công; nếu không kịp, trình bày kiến trúc bằng lời + code, không bấm máy |
| Ghép & kích hoạt SOS qua đồng hồ **Garmin thật** | 🛑 **hoàn toàn chưa test với phần cứng thật**, còn 1 bug crash Bluetooth mới vá nhưng **chưa commit** | Không demo live; trình bày như "kiến trúc đã triển khai, đang chờ kiểm thử phần cứng thật" kèm xem nhanh `GarminBridgeService.kt` nếu hội đồng muốn xem code |
| Bám theo Emergency SOS hệ thống (ColorOS, bấm nguồn 5 lần) | 🛑 bị Android 13+ chặn ở bước cấp quyền Trợ năng trên máy test thật | Không đưa vào kịch bản chính; nếu bị hỏi, trả lời thẳng đây là giới hạn nền tảng Android đã xác minh, không phải thiếu sót thiết kế |

### Câu hỏi hội đồng có thể hỏi
- *"Vì sao cảm biến giả lập trên đồng hồ lại tạo SOS thật thay vì chỉ demo suông?"* → Vì mục tiêu
  là chứng minh **toàn bộ đường đi thật** từ sự kiện cảm biến tới thông báo gia đình, không phải
  chỉ vẽ UI; máy ảo Wear OS không có gia tốc kế thật nên nút giả lập là cách duy nhất kích hoạt
  đúng luồng backend thật khi demo.
- *"Chuỗi số liệu chạy trước khi đếm ngược (vd 1.0g → 0.9g → ... → 3.2g) có phải dữ liệu cảm biến
  thật không?"* → Không — đó là chuỗi hiển thị cố định trong code, thuần hiệu ứng hình ảnh để minh
  hoạ tín hiệu "đang biến động" thay vì một con số tĩnh. Phần thuật toán phân tích tín hiệu thật (tự
  kết luận bất thường từ dữ liệu cảm biến) đã thiết kế và code thử xong, nhưng nhóm **chủ động hoãn**
  triển khai đầy đủ tới sau mùa bảo vệ để ưu tiên ổn định, không phải thiếu sót — đây là câu trả lời
  trung thực, không né tránh.
- *"Vì sao có lúc nút giả lập bị mờ, bấm không được?"* → Đó là lớp kiểm tra điều kiện được thêm để
  tránh demo nhầm: nút chỉ bấm được khi gia đình đã bật SOS, wearable đã bật SOS, và (riêng té ngã)
  đã bật tự tạo cảnh báo té ngã — đúng những điều kiện backend dùng để quyết định có tạo cảnh báo hay
  không. Nếu thiếu 1 điều kiện, giao diện hiện rõ lý do ngay khi bấm, thay vì để chờ 20 giây rồi mới
  biết không có gì xảy ra.
- *"Đồng hồ Garmin thật có dùng được chưa?"* → Kiến trúc bridge đã code xong và build được, nhưng
  nhóm **chủ động chưa** công bố đã sẵn sàng vì chưa kiểm thử trên phần cứng Garmin thật — đây là
  câu trả lời trung thực, không né tránh.
- *"Nếu điện thoại mất mạng lúc té ngã thì sao?"* → Cảnh báo hiện tại cần API thật thành công mới
  coi là đã gửi; đây là giới hạn đã biết của thiết kế hiện tại (không có hàng đợi gửi lại offline),
  có thể nêu là hướng cải tiến tương lai nếu bị hỏi sâu.

---

## 7. Scenario 5 — Family Album & Face Recognition

### Mục tiêu
Chứng minh album gia đình có AI hỗ trợ gắn tên thành viên vào ảnh, nhưng **con người luôn là người
quyết định cuối cùng** (không có tag nào được tạo tự động chỉ vì AI tự tin).

### Vai trò & thiết bị
Dùng tài khoản **Manager (Bố)** xuyên suốt scenario này — 1 số thao tác (duyệt kiểm duyệt thủ công)
hiện chỉ hiện trên tài khoản Manager, chưa hiện trên Deputy dù tài liệu API mô tả là Manager/Deputy
đều được (xem Rủi ro).

### Chuẩn bị dữ liệu — bắt buộc làm trước ngày bảo vệ
1. Chuẩn bị sẵn **3-5 ảnh rõ mặt, mỗi ảnh 1 khuôn mặt duy nhất**, ánh sáng tốt, dung lượng vừa phải
   cho từng thành viên sẽ demo — enroll thử trước, xác nhận **"Kiểm tra ảnh"** trả `canEnroll=true`
   rồi mới yên tâm để dành demo live (ảnh mờ/nhiều mặt/quá nặng sẽ bị chặn ngay bước kiểm tra).
2. Upload sẵn vài tấm ảnh gia đình **trước** ngày bảo vệ, chờ AI kiểm duyệt xong (chuyển trạng
   thái `SAFE`) — không demo bước "AI nhận diện khuôn mặt" ngay trên ảnh vừa upload trong lúc
   đang trình bày, vì ảnh có thể còn đang chờ duyệt vài giây tới vài chục giây.
3. Chỉ chuẩn bị **ảnh tĩnh** cho phần demo xem chi tiết — xem Rủi ro về việc phát video.

### Kiến trúc vận hành
- File ảnh/video trả về dạng **signed URL có hạn** — không cache lâu, mỗi lần mở lại màn có thể
  URL đã đổi (bình thường, không phải lỗi).
- AI nhận diện khuôn mặt tự kích hoạt khi mở chi tiết 1 ảnh **đã `SAFE`, chưa từng quét, chưa có
  tag** — không cần bấm nút; có nút quét thủ công dự phòng nếu ảnh đã từng quét trước đó.
- Với ảnh có nhiều khuôn mặt, BE **chấm điểm riêng từng khuôn mặt** rồi đưa ứng viên tốt nhất theo
  từng khuôn mặt (không gộp chung 1 điểm cho cả ảnh).
- Gợi ý tag **không bao giờ tự trở thành tag thật** — chỉ khi người dùng bấm ✓ Xác nhận, BE mới
  ghi bản ghi `AlbumTag` chính thức; bấm ✗ chỉ từ chối gợi ý, không xoá gì khác.

### Các bước demo chi tiết

| # | Ai làm | Thao tác |
|---|---|---|
| 1 | Bố | Vào **Thành viên → chọn 1 người → Face Profile** → chọn 3-5 ảnh đã chuẩn bị sẵn → bấm **"Kiểm tra ảnh"** → thấy hợp lệ |
| 2 | Bố | Tick đồng ý điều khoản → bấm **"Gửi tạo Face Profile"** → chờ (có thể tới ~2 phút vì BE phải tạo embedding khuôn mặt) |
| 3 | Bố | Vào **Album** → bấm nút thêm ảnh (FAB) → chọn 1 ảnh mới từ thư viện → nhập mô tả + chọn quyền xem ("Gia đình") → tải lên — minh hoạ bước upload thật, live |
| 4 | Bố | Mở lại 1 ảnh đã chuẩn bị **từ trước** (đã `SAFE`) chứa mặt thành viên vừa enroll → màn tự động chạy **"Đang quét khuôn mặt…"** (hoặc bấm nút quét thủ công nếu cần) |
| 5 | Bố | Sau ~vài giây, thấy khung khuôn mặt phát hiện được kèm **tên gợi ý + % độ tin cậy** |
| 6 | Bố | Bấm **✓ Xác nhận** trên gợi ý đúng → tag chính thức được tạo, avatar thành viên hiện trên ảnh |
| 7 | Bố | (Nếu có gợi ý sai) bấm **✗** để từ chối — minh hoạ AI không phải lúc nào cũng đúng và luôn có đường từ chối |
| 8 | Bố | Vào tab **"Thành viên"** trong Album → chọn đúng người vừa tag → thấy album lọc đúng chỉ ảnh có mặt người đó |
| 9 | Bố *(tuỳ chọn, chỉ tài khoản Manager)* | Bấm icon 🛡️ trên AppBar Album → xem **hàng đợi kiểm duyệt** — minh hoạ AI cũng tự chấm điểm rủi ro nội dung ảnh (không chỉ khuôn mặt) |

### Kết quả mong đợi
- Face Profile chuyển trạng thái đã đăng ký thành công.
- Ảnh mới upload lên đúng album, đúng quyền xem đã chọn.
- Gợi ý tag hiện đúng tên + % tin cậy; sau khi xác nhận, ảnh có tag thật, lọc được theo thành viên.

### Rủi ro & phương án dự phòng
- 🛑 **Không mở chi tiết file video trong Album để demo phát video** — màn chi tiết hiện dùng
  `Image.network` cho mọi loại media, dự án **chưa có package phát video** nào — mở video sẽ chỉ
  ra icon lỗi. Chỉ demo ảnh tĩnh; nếu muốn nhắc tới video, chỉ dừng ở bước "tải lên thành công",
  không mở chi tiết.
- ⚠️ **Dùng đúng tài khoản Manager** cho bước 9 (duyệt kiểm duyệt) — code hiện tại chỉ hiện nút này
  cho `UserRole.manager`, dù tài liệu API và 1 dòng comment cạnh đó ghi là Manager/Deputy đều được.
  Đây là điểm lệch giữa code và tài liệu, tài khoản Deputy sẽ **không thấy nút** — không phải do
  thao tác sai.
- Nếu ảnh vừa upload chưa kịp chuyển `SAFE` lúc demo, mục Face bị khoá kèm thông báo yêu cầu chờ
  kiểm duyệt — đây là hành vi đúng, không phải lỗi; dùng ảnh đã chuẩn bị sẵn (bước 4) để né tình
  huống này hoàn toàn.
- "Đã ghim" trong Bộ sưu tập và nút "Tạo album" (album con) — **chỉ là trạng thái cục bộ trên máy/
  đang bị ẩn**, chưa lưu lên server và chưa có endpoint thật. Không hứa hẹn với hội đồng đây là
  tính năng đã hoàn thiện nếu bị hỏi sâu về tổ chức album.

### Câu hỏi hội đồng có thể hỏi
- *"Độ chính xác nhận diện khuôn mặt bao nhiêu %?"* → Không có con số benchmark chính thức để công
  bố (ngoài phạm vi FE, do BE/mô hình AI xử lý) — trả lời an toàn: hệ thống hiển thị đúng % tin cậy
  BE trả về cho từng gợi ý, và **luôn cần con người xác nhận**, nên sai số của mô hình không trực
  tiếp tạo ra dữ liệu sai.
- *"Ảnh nhạy cảm có được kiểm duyệt không?"* → Có — mọi ảnh qua 1 lớp kiểm duyệt AI heuristic
  (`riskScore`) trước khi chuyển `SAFE`; Manager có màn duyệt tay riêng cho ảnh bị gắn cờ.

---

## 8. Lịch trình gợi ý cho buổi demo

Tổng ~20-25 phút demo (điều chỉnh theo thời lượng thực tế hội đồng cho phép), sau 2 phút tổng quan
kiến trúc ở mục 1:

| Scenario | Thời lượng gợi ý | Ghi chú |
|---|---|---|
| 1. Onboarding & Role | 3-4 phút | Chạy thật từ tài khoản trắng |
| 2. AI Task & Calendar | 4-5 phút | Chỉ demo nhánh gộp đủ thông tin trong 1 câu |
| 3. AI Finance | 4-5 phút | Mô hình tài chính đã chuẩn bị sẵn trước, không dựng live |
| 4. SOS & Wearable | 5-6 phút | Ưu tiên nhánh ✅ trong bảng rủi ro; không ép demo phần 🛑 |
| 5. Album & Face | 4-5 phút | Face Profile + ảnh đã chuẩn bị sẵn trước |

Nếu bị rút ngắn thời gian: giữ nguyên Scenario 1 (mở đầu bắt buộc) + chọn 2 trong 4 scenario còn
lại có mức rủi ro thấp nhất theo bảng ở mỗi mục (khuyến nghị giữ Scenario 2 và 5, lùi Scenario 4
về phần hỏi đáp nếu thời gian eo hẹp vì đây là phần cần giải thích rủi ro nhiều nhất).

---

## 9. Phụ lục — mapping nhanh tính năng ↔ file nguồn (dùng khi hội đồng hỏi sâu)

| Tính năng | Provider | Màn hình chính |
|---|---|---|
| Đăng ký/đăng nhập/gia đình | `auth_provider.dart`, `invitation_provider.dart` | `family_setup_screen.dart`, `join_family_screen.dart`, `invitation_requests_screen.dart` |
| Vai trò/quyền | `lib/models/user.dart` | `member_detail_screen.dart` |
| AI Chatbot | `ai_chatbot_provider.dart` | `ai_assistant_screen.dart` |
| Nhiệm vụ | `task_provider.dart` | `task_management_screen.dart`, `child_tasks_screen.dart` |
| Lịch | `calendar_provider.dart` | `calendar_screen.dart` |
| Tài chính | `finance_provider.dart`, `wallet_provider.dart` | `wallet_screen.dart`, `budget_plan_screen.dart`, `financial_goal_screen.dart`, `finance_reports_screen.dart` |
| SOS | `sos_provider.dart` | `sos_screen.dart`, `sos_settings_screen.dart` |
| Wearable (Wear OS) | `wearable_provider.dart` | `lib/wear/`, `wearables_screen.dart` |
| Wearable (Garmin) | `lib/services/garmin_bridge.dart` | `GarminBridgeService.kt` (native) |
| Album/Face | `album_provider.dart`, `album_face_provider.dart`, `face_profile_provider.dart` | `album_screen.dart`, `album_face_section.dart`, `album_people_screen.dart` |
| Thông báo | `notification_provider.dart` | `notifications_screen.dart` |
