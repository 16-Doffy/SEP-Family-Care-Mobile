# Family Care Mobile — AI Handoff (Latest)

Last updated: **2026-08-07**

## Snapshot hiện hành 2026-08-07 — Trợ lý AI hoàn chỉnh, vá rò rỉ dữ liệu giữa hai tài khoản, đã merge lên main

> Snapshot này mới hơn toàn bộ phần 2026-08-04 bên dưới. Khi có mâu thuẫn,
> dùng trạng thái ở đây và source hiện tại.

### Trạng thái Git chốt cuối ngày

- **`NDuy` = `main` = `origin/NDuy` = `origin/main` = `9dda7be`.** Đã merge
  fast-forward, không có merge commit thừa, `git diff main NDuy` rỗng hoàn toàn.
- `origin/giap` còn ở `0a41e32`, **đi sau main 9 commit**. Cần báo Giáp
  `git merge origin/main` sớm: 9 commit này chạm `lib/services/api_client.dart`
  và **17 file provider**, để lâu là conflict dồn.
- Mốc cứu hộ: tag `backup/main-before-merge-20260807` trỏ `0a41e32`; nhánh
  `backup/ai-before-reword-20260807` giữ bản trước khi viết lại lời commit.
- Đã verify 5 commit của Giáp còn nguyên trong main bằng `merge-base
  --is-ancestor` (nén logo, SOS qua wearable event, ngắt kết nối thiết bị đeo,
  test mapping).

### 9 commit của phiên này (đã lên main)

```
9dda7be  docs(bàn giao): chốt trạng thái phiên Trợ lý AI và rò rỉ dữ liệu
b77d7e2  fix(bảo mật): dọn nốt 17 provider còn giữ dữ liệu tài khoản cũ
e5aeb22  feat(trợ lý AI): tải thêm hội thoại và tin nhắn cũ
57c5f8c  fix(trợ lý AI): đỡ đúng hình dạng response BE mô tả
92cea20  feat(trợ lý AI): gợi ý câu hỏi theo vai trò + nhóm mô hình tài chính
7c58bfa  fix(bảo mật): dọn dữ liệu phiên cũ khi đổi tài khoản
46c12fe  chore(tài liệu): bỏ file báo cáo BE khỏi repo
932c63b  fix(trợ lý AI): thẻ đề xuất phân biệt đã thực hiện / từ chối / hết hạn
f4b37bb  fix(trợ lý AI): định dạng tiền và giờ, sửa 403/409/410, reload đúng tháng
```

Lưu ý quy trình: **không commit tài liệu báo cáo BE vào repo nữa** (đã gỡ
`BAO_CAO_BE_AI_CHATBOT_2026-08-07.md` ở `46c12fe`). Nội dung gửi BE để trong
tin nhắn, chỉ tóm tắt lại trong tài liệu bàn giao này.

### 12 commit kéo từ main về đầu phiên (việc của Giáp)

- `2171854` — thiết bị đeo: đủ 5 loại sự kiện cảm biến, nối lại 2 màn đồng hồ bị
  mất lối vào.
- `2057edd` — thiết bị đeo: tin nhắn nhanh sửa được, vá provider thiếu ở
  entrypoint đồng hồ.
- `883a81b` — SOS: tự tạo cảnh báo khi điện thoại phát hiện té ngã.
- `ef28135` — khuôn mặt: khôi phục 3 lệch schema `face-suggestions` bị merge ghi
  đè trước đó.
- `c52f62b` — tài chính: xem và thao tác theo kỳ tháng, không còn kẹt ở tháng
  hiện tại.
- `e9532cf` — thiết bị đeo: ghép nối theo contract mới, một tài khoản một thiết bị.
- `7b9605f`, `e580b97` — hoàn thiện giao diện Wear OS và SOS gửi từ đồng hồ.
- `8e574d5` — Android: thêm biểu tượng tròn cho launcher.
- `bc624b2` — docs: thêm `CLAUDE.md`, bản dump Swagger mới, phân tích tiến trình FE.
- `13ea351`, `f947469` — các commit đồng bộ main ↔ giap.

Tổng: 54 file, +6741 / −1809 dòng. File mới đáng chú ý:
`lib/services/fall_detector_service.dart`, `lib/services/sos_location.dart`,
`lib/models/finance_period.dart`, `lib/widgets/month_switcher.dart`,
`lib/widgets/month_start_checklist.dart`, `lib/widgets/fall_countdown_dialog.dart`,
`lib/providers/wear_quick_message_provider.dart`, `lib/wear/wear_root.dart`,
`lib/wear/wear_widgets.dart` cùng 5 màn Wear mới (calendar, map, notifications,
quick message, tasks).

### Verification cuối phiên (chạy trên đúng cây đã lên main)

- `flutter analyze --no-fatal-infos`: **0 error, 0 warning**, còn đúng 20
  info-lint có sẵn từ trước — không phát sinh mới.
- `flutter test`: **252/252 PASS** (đầu phiên 160). 6 bộ test mới của phiên này:
  `ai_feature_access_test`, `ai_pending_action_contract_test`,
  `ai_send_response_test`, `ai_prompt_role_test`, `ai_pagination_test`,
  `ai_session_reset_test`, `session_reset_registered_test`.
- Lưu ý khi format: **đừng chạy `dart format lib/providers/`** trên cả thư mục.
  Một số file (nhất là `chat_provider.dart`) chưa theo style hiện hành, format
  cả thư mục sinh ra 200+ dòng nhiễu không liên quan. Chỉ format file mình sửa.

### 🔴 Rò rỉ dữ liệu giữa hai tài khoản — nghiêm trọng nhất phiên này

Phát hiện khi chạy thật, không đọc code nào ra được.

**Tái hiện:** đăng nhập Trưởng nhóm → chat AI về tài chính → đăng xuất → đăng
nhập Thành viên trên cùng máy → mở Trợ lý AI → **hiện nguyên hội thoại của
Trưởng nhóm**, gồm số liệu chi tiêu và sự kiện lịch.

**Backend KHÔNG sai.** Danh sách hội thoại trả về cho Thành viên là **rỗng**,
đúng như Swagger mô tả. Rò rỉ hoàn toàn ở app: 21 provider khai ở app scope
trong `main.dart` sống suốt vòng đời ứng dụng, còn `logout()` chỉ xóa token và
thông tin đăng nhập, không đụng dữ liệu provider đang giữ trong RAM.

**Cách sửa:** `ApiClient.clearSession()` là điểm nghẽn duy nhất của cả ba đường
kết thúc phiên (bấm đăng xuất, phiên hết hạn, bị buộc đăng xuất khi 401). Thêm
danh sách listener ở cấp static, `clearSession` gọi hết khi chạy. Danh sách cố
tình **không** bị `clearSession` xóa — provider đăng ký một lần lúc khởi tạo,
phải còn hiệu lực cho mọi lần đăng xuất sau. Một listener ném lỗi không chặn các
listener còn lại.

**18 provider** đã có `resetForNewSession()` và tự đăng ký trong constructor.
Ba cái có tài nguyên sống được xử lý riêng, không chỉ xóa field:

- `NotificationProvider` gọi `stopRealtime()` ngắt socket trước — giữ kết nối
  của tài khoản cũ thì tài khoản mới nhận thông báo không phải của mình.
- `ChatProvider` dùng lại `clear()` sẵn có, hàm này dừng luôn timer polling.
- `SosProvider` xóa cả cảnh báo, danh bạ khẩn cấp và cài đặt.

**Cố ý KHÔNG dọn 4 cái:** `AuthProvider` (chính nó quản phiên), và
`ThemeModeController` / `TabConfigProvider` / `WearQuickMessageProvider` — tùy
chọn giao diện của **máy**, không phải dữ liệu gia đình, đổi tài khoản vẫn giữ
là đúng mong đợi.

Test canh gác `test/session_reset_registered_test.dart` quét `main.dart`, đối
chiếu từng provider với file nguồn, đỏ ngay nếu thiếu đăng ký hoặc thiếu hàm
reset. Thêm provider mới mà quên dọn là biết liền.

### Trợ lý AI — 8 lỗi FE đã sửa trong ngày

- **Sai tên feature key (lỗi im lặng).** `FeatureAccess` đọc `ai.enabled` và
  `ai.chatbot`; cả hai KHÔNG nằm trong 26 key chính thức BE khai ở
  `CreateSubscriptionPlanDto.featureAccess`. `flag()` trả `false` cả khi key
  không tồn tại, nên dòng "Tính năng AI" và "Trợ lý AI" ở màn Gói đăng ký không
  bao giờ hiện, kể cả gói trả phí. Đã đổi sang `ai.assistant` (giữ tên cũ làm
  alias cho plan chưa migrate) và thêm `officialKeys` + `officialKeyLabels` để
  màn Gói đăng ký duyệt đúng 26 key thay vì liệt kê tay. Bốn key FE tự bịa khác
  cũng bị bỏ cùng lúc: `finance.advanced`, `reports.advanced`, `sos.enabled`,
  `storage.unlimited`, `families.max`.
- **Gate theo gói.** `AiChatbotProvider.bootstrap()` nay gọi
  `fetchFeatureAccess()` trước; biết chắc gói không có `ai.assistant` thì dừng,
  không gọi endpoint nào và hiện `_UpgradePanel` (nút "Xem gói đăng ký" chỉ hiện
  với Manager theo `AppUser.canManageSubscription`). Vẫn **fail-open** khi BE trả
  `featureAccess` rỗng, theo đúng convention đã ghi trong `feature_access.dart`.
- **Gợi ý câu hỏi, chia theo vai trò.** Màn rỗng trước đây chỉ có hai dòng chữ,
  người dùng không biết hỏi gì nên phần hỏi đáp gần như không ai dùng dù đã chạy
  được từ lâu. Nay là bảng gợi ý, và **phân nhánh theo `AppUser.canManageFinance`**
  (đúng với Trưởng nhóm + Phó nhóm):
  - Quản lý: 4 nhóm — tra cứu tài chính, **mô hình tài chính & ngân sách** (mô
    hình đang áp dụng, hũ vượt mục tiêu, ngân sách còn lại, đã chia quỹ chưa),
    tra cứu nhiệm vụ & lịch, và nhờ AI tạo.
  - Thành viên: 3 nhóm đúng phạm vi — việc của tôi, chi tiêu của tôi, lịch gia
    đình. **Không có nhóm "Nhờ AI tạo"**, vì Thành viên không có quyền
    `canManageFinance` / `canManageTasks` / `canManageCalendar`; mời họ làm là
    dẫn thẳng vào ngõ cụt của BE (xem mục "Cần báo BE" #1). Có thêm dòng giải
    thích để họ không tưởng app lỗi.
  - Mọi câu của Thành viên dùng ngôi "tôi" thay vì "nhà mình" — giảm bớt lỗi
    đại từ trong câu trả lời của AI (mục "Cần báo BE" #6).
  - Dải chip ngang cũng đổi theo vai trò, chỉ hiện khi hội thoại đã có tin nhắn.
  - Danh sách tách ra hàm top-level `aiPromptGroupsFor()` để khóa được bằng test.

- **`preview` in dữ liệu thô ra cho người dùng đối chiếu.** `preview` là thứ
  DUY NHẤT người dùng nhìn trước khi bấm xác nhận, nhưng đang in nguyên value:
  người nói "9h sáng mai" mà thẻ hiện `2026-08-08T02:00:00.000Z` (lệch 7 tiếng,
  không đọc nổi), tiền hiện `200000` không dấu phân cách. Nay có
  `formatAiPreviewValue`: giờ → `09:00 08/08/2026` theo giờ máy, tiền →
  `200.000 ₫`, object lồng lấy `name`/`title`, null và mảng rỗng thành dấu gạch.

- **`403` lúc xác nhận báo sai nguyên nhân.** BE nói rõ 403 ở `confirm-action`
  nghĩa là **vai trò** không được phép tạo, nhưng FE dùng chung câu với 403 lúc
  chat nên hiện "Bạn chưa có quyền dùng Trợ lý AI trong gói hiện tại" — Thành
  viên bị từ chối lại tưởng phải đi nâng gói. Đã tách theo ngữ cảnh bằng cờ
  `isAction`.

- **Thẻ kẹt ở "Chờ xác nhận" sau `409`/`410`.** Hai mã này đều nghĩa là trạng
  thái thật ở server đã khác cái FE đang vẽ, nhưng FE chỉ hiện lỗi mà không tải
  lại, nên bấm mãi cũng ra đúng lỗi đó. Nay tự `fetchMessages()`.

- **Reload lịch sai tháng.** `CalendarProvider.fetchEvents` chỉ tải đúng MỘT
  tháng, FE lại luôn truyền tháng hiện tại — sự kiện "9h sáng mai" vào ngày cuối
  tháng đã sang tháng sau, xác nhận xong mở lịch không thấy gì. Nay
  `calendarMonthToReload()` lấy tháng từ `startTime` trong preview.

- **Xác nhận thành công vẫn hiện cảnh báo đỏ.** Giao dịch đã vào sổ, quỹ đã trừ,
  mà thẻ hiện dòng đỏ "Đề xuất đã hết hạn hoặc đã được xử lý" — vì UI chỉ hỏi
  `isPending` rồi gộp mọi trạng thái kết thúc vào một câu. Nay có
  `AiActionOutcome` gồm `pending / completed / rejected / expired / failed`;
  Swagger chưa khai enum `status` nên mọi giá trị kết thúc không phải từ
  chối/hết hạn/lỗi đều coi là **đã thực hiện**, thay vì mặc định báo đỏ. Chỉ còn
  `PENDING` quá `expiresAt` mới là hết hạn thật.

- **Phân trang bị kẹt ở trang đầu.** Swagger khai `page`/`limit` cho hai endpoint
  GET nhưng FE cứng `page=1`: quá 20 hội thoại hoặc quá 50 tin nhắn là mất hẳn
  phần còn lại. Nay có `loadMoreConversations()` / `loadMoreMessages()` theo đúng
  pattern `fetchMoreEntries()` của `WalletProvider`, kèm hàng "Tải thêm". Gộp
  trang sau **theo id** thay vì nối mù; tin nhắn gộp xong sắp lại theo thời gian
  nên đúng dù BE trả mới-nhất-trước hay cũ-nhất-trước (Swagger không nói).


- **actionType lạ không còn hỏng im lặng.** Trước đây `switch` trong
  `_confirmAndReload` không có nhánh `default`: BE thêm loại mới thì người dùng
  bấm xác nhận, BE tạo dữ liệu thật, app không refresh gì — nhìn như không có
  chuyện gì xảy ra. Nay `AiPendingAction.isKnownActionType` phân biệt được, loại
  lạ thì refresh cả ba nguồn (task, ví, lịch, mỗi nguồn bọc try riêng để một lỗi
  không chặn hai nguồn kia) và hiện mã `actionType` thô ngay trên thẻ đề xuất.

### Đối chiếu contract BE — đã khớp đủ

BE chốt hỗ trợ 3 `actionType`: `CREATE_TASK`, `CREATE_LEDGER_ENTRY`,
`CREATE_CALENDAR_EVENT`. Đã soi từng dòng yêu cầu với code:

- **7/7 operation AI Chatbot trong Swagger đều đã gán**, hai chiều đều sạch:
  không endpoint nào bị bỏ quên, FE cũng không gọi endpoint AI nào ngoài Swagger.
  Ngoài 7 cái đó provider chỉ gọi thêm `GET /families/{id}/subscription` để gate
  theo gói.
- `ApiClient` bóc envelope `{success, data}`, nên `data['pendingAction']` đọc
  đúng tầng như ví dụ BE gửi.
- Reload sau confirm đúng yêu cầu: nhiệm vụ → `fetchTasks()`; giao dịch →
  `fetchWallets()` (kéo cả overview, summary, entries, jars, report); lịch →
  `fetchEvents()` theo tháng của `startTime`.
- Không tự tạo dữ liệu từ `preview` — `_confirmAndReload` chỉ gọi `fetch*`.
- **Lệch có chủ ý:** BE ghi nhãn "Xác nhận tạo **công việc**", FE dùng "Tạo
  **nhiệm vụ**" cho khớp từ ngữ toàn app (tab dưới, "Nhiệm vụ hôm nay"…).

Hai lỗ hổng phát hiện ở vòng đối chiếu cuối, đã sửa ở `57c5f8c`:

1. **Response chỉ có `pendingAction` thì thẻ bị nuốt mất.** Ví dụ trong contract
   của BE chứa đúng một khối `pendingAction`, không kèm `aiMessage`/`message`/
   `content`. Code cũ chỉ biết *gắn* đề xuất vào bong bóng có sẵn → rẽ hết nhánh
   rồi thoát, người dùng gửi tin xong màn hình trống trơn. Nay có nhánh cuối tự
   dựng bong bóng mang đề xuất.
2. **Lớp chống rò rỉ đặt sai chỗ** (do chính commit trước gây ra): phép kiểm nằm
   trong `fetchConversations()`, mà `sendMessage()` cũng gọi hàm đó — hội thoại
   vừa tạo chưa lọt vào 20 bản ghi đầu là **xóa sạch tin vừa gửi**. Đã chuyển
   sang `bootstrap()`.

### Kiểm thử runtime trên emulator (gia đình NDuy)

Chạy thật, không suy luận. Tài khoản Trưởng nhóm và Thành viên đều đã thử.

| Nhánh | Bằng chứng |
|---|---|
| Gate theo gói | BE trả **đủ 26 key chính thức**, `ai.assistant: true` |
| Hỏi đáp | AI trả đúng số liệu gia đình |
| `CREATE_LEDGER_ENTRY` | quỹ **50.000.000 → 49.800.000 đ** |
| `CREATE_TASK` | tạo + từ chối đều đúng |
| `CREATE_CALENDAR_EVENT` | thẻ hiện `09:00 08/08/2026`, có push "Sự kiện lịch mới" |
| Đổi tài khoản | sau fix: Thành viên thấy màn rỗng sạch, không còn dấu vết |
| Gợi ý theo vai trò | đã xem tận mắt cả hai vai trò |
| Ngắt socket khi đăng xuất | log `NotifSocket: disconnected`, không provider nào ném lỗi |

**✅ Câu hỏi bảo mật RBAC đã có đáp án — BE làm đúng, bỏ khỏi danh sách lo ngại.**
Cùng câu "Tháng này nhà mình đã chi bao nhiêu?": Trưởng nhóm nhận **200.000đ**,
Thành viên nhận **0đ**. AI scope theo quyền người hỏi, không có cửa sau vòng qua
phân quyền.

**Chưa test được:** `403` khi Thành viên xác nhận đề xuất (BE không phát thẻ cho
Thành viên — xem mục #1 dưới); `409`/`410` (không kích được từ UI, cần đợi hết
hạn hoặc thao tác phía server). Logic hai mã này đã có unit test phủ nhưng
**chưa xác minh runtime** — đừng ghi là đã test.

### ✅ BE đã trả lời đủ 6 mục (2026-08-07) — contract chốt

BE phản hồi bằng văn bản, đã ghi vào `API_DOCS.md` mục **AI Chatbot**. Tóm tắt
và việc FE phải làm:

| Mục | BE trả lời | FE phải làm |
|---|---|---|
| 1. Member ghi thu chi | Chọn hướng (b): sửa prompt để AI **không** nói "vui lòng xác nhận" khi không có `pendingAction`. `CREATE_LEDGER_ENTRY` chỉ mở cho `FAMILY_MANAGER` + `DEPUTY_MEMBER` | **Không** — FE đã ẩn sẵn gợi ý tạo dữ liệu với Thành viên |
| 2. Swagger thiếu schema | Đồng ý bổ sung response DTO cho cả 7 endpoint + khai enum `actionType` | **✅ BE đã ship** (bản dump 2026-08-07 có `AiActionType`, `AiActionStatus`, `AiPendingActionResponseDto`…). Đối chiếu lại thì bắt được bug thật: `AiConversationLastMessageResponseDto` dùng `messageContent` chứ không phải `content` — dòng xem trước hội thoại từng trống trơn. Đã sửa ở `746a83d` |
| 3. `status` chính thức | Đúng **4 giá trị**: `PENDING`, `CONFIRMED`, `REJECTED`, `EXPIRED`. **Chưa có `CANCELED`/`FAILED`** | Đã siết `AiPendingAction.confirmedStatuses` + test |
| 4. `expiresAt` | **Có, ISO UTC thật** (`Date.toISOString()`, đuôi `Z`), interceptor không convert timezone | **Không** — FE parse đúng sẵn, đã thêm test khẳng định |
| 5. Ba key AI phụ | Chỉ là **cờ điều khiển hành vi trong chatbot**, không phải endpoint riêng, BE cũng chưa guard | **Không gate theo ba key này**, chỉ đọc để hiển thị quyền lợi gói |
| 6. Đại từ trong câu trả lời | Đồng ý sửa: Member → "bạn", Manager/Deputy → "gia đình" | **Không** — thuộc prompt BE |

**Field mới BE nhắc tới:** sau confirm thành công, `result.id` là id bản ghi vừa
tạo. FE **hiện chưa parse** field này (không cần, vì đã refetch messages). Có thể
dùng sau để deep-link tới bản ghi vừa tạo — chưa làm, đừng tưởng là đã có.

**Còn nợ, chưa đổi:** `403`/`409`/`410` vẫn **chưa xác minh runtime**. Mục 1 và 2
phải chờ BE ship xong mới test lại được. Khi test lại mục 1, dùng đúng câu
*"Ghi nhận khoản chi 200.000 cho ăn uống hôm nay"* bằng tài khoản
`FAMILY_MEMBER` — kỳ vọng **không có thẻ xác nhận**, câu trả lời nói rõ cần nhờ
Trưởng nhóm/Phó nhóm.

### Audit contract AI Chatbot lần 2 — BE gửi kèm file contract chính thức

BE gửi thêm file `AI Chatbot contract` (markdown, có mục Pending action /
Permission behavior / Feature flags) xác nhận lại đúng 6 mục ở trên. Đọc lại
toàn bộ `ai_chatbot.dart` + `ai_chatbot_provider.dart` (full file, không phải
đoạn trích) để đối chiếu — **hầu hết đã đúng từ các lần audit trước**, không
có gì bị merge với Giáp làm lệch:

- `actionType` (3 giá trị), `status` (4 giá trị, không `CANCELED`/`FAILED`),
  `expiresAt` parse UTC không cắt `Z`, card chỉ hiện khi có `pendingAction`,
  reload đúng module, 409/410 tự đồng bộ lại thẻ, 3 key gói cước không gate
  màn AI — **tất cả khớp contract, không sửa gì**.
- Sửa đúng 1 chỗ: câu báo lỗi `403` lúc `confirm-action` trong
  `_friendlyError` chỉ nhắc "Trưởng nhóm", thiếu "Phó nhóm" — trong khi
  contract nói rõ `propose_create_ledger_entry` mở cho **cả**
  `FAMILY_MANAGER` **và** `DEPUTY_MEMBER`. Màn rỗng của Thành viên
  (`ai_assistant_screen.dart`) đã viết đúng "Trưởng nhóm và Phó nhóm" từ
  trước — chỉ riêng câu lỗi này bị sót. Đã sửa.
- Xác nhận lại: vấn đề chính (Member không nên nhận `pendingAction`) là lỗi
  **prompt/guard phía BE**, không phải chỗ nào FE sửa được — FE đã đúng sẵn
  (không có `pendingAction` thì không hiện thẻ).

### 📋 Nội dung 6 mục đã gửi BE (giữ lại để đối chiếu)

### 🔴 Bug lệch giờ 7 tiếng ở sổ thu chi — phát hiện khi verify giao dịch AI tạo

Không liên quan module AI, nhưng lộ ra khi verify runtime `CREATE_LEDGER_ENTRY`.
Ảnh hưởng **toàn bộ sổ thu chi**, mọi giao dịch, không riêng giao dịch AI tạo.

**Bằng chứng runtime:** tạo khoản chi thủ công lúc 20:19:00 giờ VN (13:19:00
UTC, verify TZ = Asia/Bangkok bằng `adb shell date`/`date -u` khớp cả emulator
lẫn host). Sổ thu chi hiện `13:18` — đúng bằng giờ UTC.

**Nguyên nhân — chứng minh bằng vòng khép kín, không suy luận:** FE tự gửi
`entryDate` bằng `DateTime.now().toUtc().toIso8601String()` (UTC chuẩn) lúc
**tạo** giao dịch (`WalletProvider.recordEntry`), nhưng `displayEntryDate` lại
cắt bỏ `Z` rồi parse như giờ naive lúc **hiển thị** — tự đọc sai dữ liệu do
chính FE gửi lên. **Lỗi FE, không phải BE.** Comment cũ trong code ghi "BE vẫn
trả hậu tố Z nhưng giữ giờ local GMT+7" — giả định này không còn đúng với
ledger (có thể BE đã đổi sang UTC thật, khớp với `expiresAt` của AI Chatbot
cũng là UTC thật).

**Đã sửa:** `WalletProvider.displayEntryDate` và `ChildWalletScreen._fmtDate`
— parse chuẩn rồi `.toLocal()` khi chuỗi thật sự UTC, giữ nguyên nếu chuỗi
naive (phòng dữ liệu cũ). Test mới: `test/wallet_ledger_date_test.dart`.
`API_DOCS.md` sửa lại dòng sai về timezone ledger.

**Không đụng:** support-request date — chưa có bằng chứng runtime mới, để
verify riêng nếu đụng tới, không suy diễn theo ledger.

**📋 Cần báo BE (phát hiện phụ, chưa xử lý):**
1. Giao dịch tự sinh từ `POST /finance/fund-allocations` có `description`
   tiếng Anh ("Allocate fund to Savings/Giving/Enjoyment/Education/
   Necessities") trong khi toàn app tiếng Việt — không tìm thấy chuỗi này ở
   bất kỳ đâu trong `lib/`, xác nhận là nội dung BE tự sinh. Không tự dịch
   cứng ở FE vì dễ vỡ nếu BE đổi tên hũ/mô hình sau này.
2. Màn Chi tiết giao dịch hiện "Số tiền: 30,000,000 đ **đ**" — lặp đơn vị.
   Phát hiện khi bấm nhầm vào giao dịch cũ lúc test, **chưa xác định được vị
   trí chính xác trong code** để phân loại lỗi FE hay do ghép chuỗi từ dữ liệu
   BE — cần soi lại trước khi sửa.

### File tạm không được commit

`.tmp_report_audit/`, `BuildDocx.cs`, `build_report6.ps1` là công cụ dựng báo cáo
docx cục bộ, cố ý để untracked. Đừng `git add -A` mà không lọc.

## Snapshot 2026-08-04 — Hoàn thành Sơ đồ Tổng thể Use Case Diagram (96 UCs / 8 Subsystems / 4 Actors / 4 External Systems)

### Use Case Diagram Tổng thể (`D:\Downloads\usecase-diagram (1).drawio`)

- **Trạng thái**: Đã hoàn thành 100%, được kiểm tra và thẩm định chi tiết cấu trúc XML.
- **4 Human Actors**:
  - `Guest` (Khách / Người dùng mới)
  - `Family Manager` (Trưởng nhóm gia đình)
  - `Family Member` (Thành viên gia đình)
  - `System Admin` (Quản trị viên hệ thống Web Admin)
- **4 External Systems**:
  - `AI Service` (Trợ lý AI Chatbot & AI Face Tags)
  - `Payment Gateway` (Cổng thanh toán gói cước)
  - `Notification Service` (Dịch vụ thông báo đẩy FCM)
  - `Wearable / GPS Device` (Đồng hồ thông minh & Định vị GPS)
- **72 Use Cases đại diện (Bao phủ trọn vẹn 100% tất cả 96 Use Cases thuộc 8 Subsystems)**:
  1. `1. Authentication & Workspace Setup` (UC09-UC13, UC69)
  2. `2. Family & Permission Management` (UC14-UC20)
  3. `3. Finance, Budget & Family Fund` (UC21-UC36, UC76-UC78, UC82-UC96)
  4. `4. Task & Reward Management` (UC37-UC49)
  5. `5. SOS, Safety & Wearable Tracking` (UC50-UC59, UC79-UC81)
  6. `6. Album & AI Face Classification` (UC72-UC75)
  7. `7. Communication, Calendar & AI Assistant` (UC60-UC68, UC70-UC71)
  8. `8. Admin System Management` (UC01-UC08)
- **Chuẩn đồ họa & Kết nối UML**:
  - 85 đường nối (`connectors`).
  - Mũi tên nét đứt `<<include>>`: chỉ từ Use Case gốc sang Use Case dịch vụ/bắt buộc.
  - Mũi tên nét đứt `<<extend>>`: chỉ từ Use Case phụ/tùy chọn về Use Case chính.
  - Dây nét liền không mũi tên nối từ Actor vào Use Case.
- **Lưu ý hoàn thiện UI trước khi xuất file**:
  - Đã nhắc người dùng chỉnh nhẹ typo `Famlily member` ➔ `Family Member`.
  - Làm sạch các thẻ ngắt dòng HTML `<br/>` trong tên hình bầu dục để khi export PNG/PDF hiển thị đẹp nhất.

## Snapshot 2026-08-02 — đồng bộ main, Finance model/hũ và Face scan

### Git / phạm vi thay đổi

- Nhánh làm việc `NDuy` đã fast-forward an toàn tới `origin/main` commit
  `1c452e1`; trước pull `main` đi trước 12 commit, không có nhánh rẽ.
- WIP được stash tạm, pull `--ff-only`, rồi khôi phục. Chỉ `API_DOCS.md` trùng
  nội dung và đã được hợp nhất giữ đủ cả hai phía; không mất code.
- Local `NDuy` hiện đi trước `origin/NDuy` 12 commit do chưa push sau khi kéo
  main. Working tree còn nhiều thay đổi cục bộ thuộc Album/SOS/Subscription,
  tài liệu và report; không commit/push nếu người dùng chưa yêu cầu.

### Finance model / category → jar — đã wire theo contract mới

- Mapping dùng đủ GET/POST/DELETE `/finance/category-jar-mappings`, luôn truyền
  `financeModelId`; mapping 5 hũ và 80/20 được tách theo từng model.
- Form tạo/sửa ledger ưu tiên `categoryId`, không gửi `jarId`; BE tự map theo
  model ACTIVE. Giao dịch cũ hoặc jar thuộc model khác đi vào `unmapped`.
- Dashboard và Báo cáo → Theo hũ gọi
  `GET /finance/reports/jar-target-actual` với active `financeModelId`; không
  còn dùng phép cộng local (`lib/utils/jar_allocation.dart` đã bị xóa).
- Parser khớp DTO live: `items[].jar`, target/actual %, target/actual amount,
  status `ON_TRACK | OVER_TARGET | UNDER_TARGET`, và `unmapped.amount`.
- Contract BE xác nhận report chỉ tính ledger `ACTIVE`, cash-out
  `EXPENSE | SUPPORT | ALLOWANCE | REWARD` trong kỳ. Jar của model cũ/khác
  model được cộng vào `unmapped.legacyJarAmount`, không cộng vào hũ mới.
- Swagger live đã có response schema/example cho mapping và
  `jar-target-actual`. Tuy nhiên GET/POST model và GET/POST/PATCH jar vẫn thiếu
  response DTO rõ ràng; đánh `[VERIFY]`, không suy diễn thêm field số dư hũ.

### Album Face AI — multi-face đã có, retry/rate-limit vừa bổ sung

- Multi-face đã đọc `data.faces[]`, mỗi face giữ candidate confidence cao nhất;
  người dùng vẫn phải bấm ✓ mới tạo tag chính thức.
- Bổ sung `FaceScanStatusInfo`: đọc `PENDING | PROCESSING | COMPLETED | FAILED`,
  `retryAllowed`, `maxProcessingSeconds` ở root hoặc object `job/scan`.
- Khi `retryAllowed=true`, FE gọi `POST .../face-scan/retry`; không tạo force
  scan mới. Lỗi `429 FACE_SCAN_FORCE_RESCAN_RATE_LIMITED` đọc
  `retryAfterSeconds`, `cooldownSeconds` hoặc header `Retry-After`, khóa nút và
  đếm ngược rõ trên UI.
- Swagger live còn thiếu success response schema cho POST scan, GET status và
  POST retry, nên parser status giữ phòng thủ và cần verify runtime với job kẹt.

### Verification 2026-08-02

- `dart analyze` trực tiếp 3 file Face/API vừa sửa: **No issues found**.
- `flutter analyze --no-fatal-infos` toàn project: **0 error, 0 warning**;
  còn 20 info-lint có sẵn ở các module khác.
- Targeted Flutter tests Face + Finance model/hũ: **21/21 pass**, gồm parser
  retry metadata, multi-face, mapping lồng, response chính xác của
  `jar-target-actual`, history allocation và ADJUSTMENT trung tính với số dư.

## Snapshot 2026-07-29 — Face AI, giao dịch theo hũ và lịch sử chia quỹ

> Đây là snapshot LỊCH SỬ. Snapshot ưu tiên nằm ở đầu tài liệu (2026-08-07).
> Phần dưới đây có thể chứa commit, API contract hoặc `[VERIFY]` đã lỗi thời.

### Git / nhánh

- Nhánh làm việc: `NDuy`.
- `NDuy`, `origin/NDuy` và `origin/main` đang đồng bộ tại commit `dfb8c6c`.
- `main` được fast-forward từ `bb368ac` lên `dfb8c6c`; không có nhánh rẽ,
  conflict hoặc merge commit thừa.
- Các commit mới nhất đã push:
  - `dfb8c6c` — `fix(tài chính): đồng bộ lịch sử chia quỹ theo contract BE mới`;
  - `6f8a744` — `fix(tài chính): gắn giao dịch chi vào đúng hũ đang áp dụng`;
  - `96961b8` — `fix(khuôn mặt): giải thích trạng thái ảnh chờ duyệt an toàn`;
  - `3d90726` — `feat(khuôn mặt): hoàn thiện kiểm tra và chọn ảnh Face Profile`;
  - `958e303` — `feat(tài chính): hiển thị thời điểm thực hiện chia quỹ`.
- Working tree vẫn có thay đổi khác chưa commit trong `AI_HANDOFF_LATEST.md`,
  `API_DOCS.md`, Album/SOS/Subscription và các file report tạm. Không stage
  chung các file này nếu chưa rà lại đúng phạm vi.

### Face Profile / Album Face AI đã kiểm tra runtime

- Face Profile cho phép chọn từng ảnh, thêm/xóa preview, đủ 3–5 ảnh mới kiểm
  tra; gọi `POST .../face-profiles/{memberId}/validate` trước khi enroll.
- FE đọc `canEnroll` và `results[]`, hiển thị pass/fail từng ảnh; chỉ bật nút
  tạo hồ sơ khi ảnh đạt và đã xác nhận đồng ý.
- Runtime đã test: 3 ảnh đạt validate, enroll thành công và member detail hiện
  trạng thái **Đã thiết lập**.
- Album media chưa SAFE hiện cảnh báo rõ **Ảnh đang chờ duyệt an toàn**; phải
  duyệt thủ công trước khi AI scan.
- Runtime đã test: ảnh SAFE quét được gợi ý thành viên, người dùng bấm xác nhận
  rồi tag chính thức được tạo. Flow hiện hành giữ rule user phải xác nhận;
  không tự tạo tag chỉ vì confidence >= 80%.

### Finance — gắn khoản chi vào hũ

- `CreateLedgerEntryDto` và `UpdateLedgerEntryDto` có `jarId`; FE đã thêm
  dropdown **Hũ chi tiêu** khi tạo/sửa giao dịch EXPENSE.
- Chỉ hiển thị hũ active thuộc đúng mô hình `ACTIVE`; có thể chuyển hũ hoặc
  chọn **Chưa gắn hũ** để bỏ liên kết.
- Runtime đã test: ghi chi `100.000đ` vào Education làm dòng Education tăng
  từ `0đ` lên `100.000đ`; số này không còn bị dồn vào **Chưa gắn hũ**.
- `POST /finance/fund-allocations` chỉ phân loại quỹ nội bộ và tạo ADJUSTMENT
  ledger để audit; không tạo tiền mới và không tự làm tăng thực chi hũ.
- Verify targeted: `flutter analyze` hai file Wallet/Provider không có lỗi;
  `test/jar_allocation_test.dart` đạt **10/10**.

### Finance — chia quỹ theo mô hình và lịch sử

- Flow: activate model → nhập số tiền/kỳ/ghi chú →
  `POST /finance/fund-allocations` → hiển thị `items[]` theo từng hũ.
- Contract BE chốt ngày 29/07/2026:
  - POST và GET history trả thêm `createdAt`, `createdByMemberId`, `note` ở
    cấp allocation;
  - GET history sort mới nhất trước theo `createdAt`;
  - history cố trả `model`, `period`, `totalAmount`, `items`, `createdAt`;
    dữ liệu legacy không khôi phục được có thể null nhưng item không bị loại;
  - unique rule là `familyId + periodMonth + periodYear`: một gia đình chỉ
    được chia một lần trong một kỳ, dù đổi model;
  - đổi active model chỉ áp dụng cho lần chia tương lai, không đổi snapshot cũ.
- FE đã đọc metadata mới ở cấp allocation, fallback timestamp từ entries cho
  legacy, giữ item nullable, sắp xếp mới nhất trước và đưa item thiếu thời gian
  xuống cuối.
- UI chi tiết hiển thị thời điểm, ghi chú, `createdByMemberId`; dữ liệu legacy
  thiếu model/kỳ/tổng/items có nhãn thay thế thay vì crash hoặc bị mất.
- Error `409 FUND_ALLOCATION_ALREADY_EXISTS` hiển thị đúng: mỗi tháng chỉ
  chia một lần kể cả đổi mô hình.
- Runtime đã test:
  - lịch sử `17:02:36` nằm trên bản `16:43:13`, ghi chú hiển thị đúng;
  - chia lại cùng kỳ trả đúng cảnh báo 409;
  - hai bản ghi trùng kỳ 7/2026 nhìn thấy trong lịch sử là dữ liệu cũ tạo trước
    khi BE áp dụng unique rule mới, không phải FE tạo thêm sau fix.
- Verify targeted: analyzer ba file contract/history không có lỗi;
  `test/fund_allocation_mapping_test.dart` đạt **5/5** (metadata mới, legacy
  nullable, sort newest-first và ADJUSTMENT không đổi tổng quỹ).

### Việc tiếp theo đề xuất

1. Test quyền chia/xem lịch sử bằng `FAMILY_MANAGER`, `DEPUTY_MEMBER` và xác
   nhận `FAMILY_MEMBER` nhận 403 đúng contract.
2. Khi xem chi tiết history, nếu không muốn lộ UUID thành viên thì đề nghị BE
   trả thêm snapshot/display name người thực hiện; hiện contract chỉ có
   `createdByMemberId` nên FE chỉ có thể hiển thị mã.
3. Tiếp tục từng module còn dở; chỉ commit/push khi người dùng yêu cầu. Commit
   message dùng tiếng Việt và tách theo chức năng.

## Snapshot đang làm 2026-07-30 — Face nhiều khuôn mặt và Category → Jar

- Đã đọc lại Swagger live ngày 30/07/2026 và tin nhắn contract BE.
- Face Album: FE nhận cả response suggestion phẳng và response nhóm theo từng
  khuôn mặt (`faces/results` + `candidates/matches`), chỉ giữ ứng viên score cao
  nhất cho mỗi face. Vẫn giữ rule: AI chỉ gợi ý, user xác nhận mới tạo tag.
- Finance: đã thêm provider/UI CRUD mapping category → jar theo từng model qua
  GET/POST/DELETE `category-jar-mappings`; sau khi activate model, màn hình ưu
  tiên mở bước cấu hình mapping.
- Tạo giao dịch mới ưu tiên `categoryId`, không gửi `jarId`, để BE tự map theo
  model ACTIVE. Giao dịch cũ không map giữ nguyên ở `unmapped`.
- Đã wire report `reports/jar-target-actual` vào tab **Theo hũ**, hỗ trợ trạng
  thái ON_TRACK / OVER_TARGET / UNDER_TARGET và fallback raw khi response chưa
  khớp parser.
- Swagger live vẫn thiếu response schema/example cho Face Suggestions,
  category-jar-mappings và jar-target-actual; cần giữ `[VERIFY]` cho tên field
  response cho đến khi có DTO/sample chính thức hoặc test runtime có dữ liệu.
- Chưa commit/push các thay đổi 30/07; chỉ thực hiện khi người dùng yêu cầu.

## 🚀 Snapshot mới nhất 2026-07-28 (Đối chiếu toàn bộ Swagger API 2026-07-28 & Verification Mobile + Web Admin)

### 📌 Trạng thái Git & Biên Dịch
- **Mobile FE (`d:\Desktop\mobile-sep`)**: `flutter analyze` clean (**0 error**, **0 warning**), `flutter test` **109 / 109 PASS 100%**.
- **Web Admin FE (`d:\Desktop\sep`)**: Next.js production build (`pnpm --filter web build`) **Compiled successfully**, 29/29 static pages.

### 🛠️ Chi Tiết Kiểm Tra & Đối Chiếu API Swagger (`familycare-swagger-2026-07-28.json`)
1. **Đối chiếu Mobile App (Flutter)**:
   - Tổng cộng 236 Non-Admin Swagger endpoints, Mobile App đã gán và hoạt động **227/236 endpoints (96.2% độ phủ)**.
   - Đã rà soát & đảm bảo phòng thủ toàn bộ 12 luồng nghiệp vụ chính: Auth, Family & Invite (mã 8 ký tự), SOS & Vị trí, Wearables, Notifications & Real-time Socket.IO, Subscriptions, Finance Module (Summary, Monthly Finance, Models/Jars, Categories, Ledger, Support Requests, Budget Plans, Goals, Reports, Alerts), Task & Reward, Calendar, Chat, Album & Face Profiles, AI Chatbot.
2. **Đối chiếu Web Admin (Next.js)**:
   - Phủ đầy đủ 100% các màn Admin: Users, Families, Subscriptions, Payments, System & Host Infrastructure, Docker containers, Audit logs, Backups & Restore, Revenue, Provisioning logs.
   - Các API Admin mới (`confirm restore`, `container stats/logs`, `family subscription/activation/provisioning logs`) đều đã có sẵn helper hooks chuẩn TypeScript trong `useAdmin.ts`.

### 📋 List 5 Điểm Cần Phản Hồi Team Backend (BE Report List)
1. **Face Profile Validate Response DTO (`POST /families/:familyId/face-profiles/:memberId/validate`)**:
   - API trả về `201 Created` thành công, nhưng Swagger OpenAPI schema chưa định nghĩa DTO mẫu JSON cho `canEnroll: boolean`, `results: Array`, `reasonCode: string`.
2. **Kế hoạch đóng góp mục tiêu (Goal Contribution Plan)**:
   - Khi tạo Kế hoạch đóng góp mới cho tháng, các khoản trích cũ (`allocations`) thực hiện trước thời điểm tạo plan không được cộng dồn vào `actualAmount` của plan mới, trừ khi được gắn với `planId`.
3. **Chuẩn hóa Timezone của các bản ghi Ledger / Support Request**:
   - Chuỗi thời gian trong response API cần được BE trả về dạng UTC chuẩn có đuôi `Z` hoặc offset `+07:00` nhất quán, tránh trả wall-clock local nhưng gắn đuôi `Z`.
4. **Trạng thái SOS Response (`SosResponseResponseDto.responseType`)**:
   - Swagger liệt kê enum gồm `VIEWED`, `CONFIRM_SAFE`, `NEED_HELP`, `RESOLVED`, `CANCELED`, nhưng summary nhắc tới `ON_THE_WAY`. BE cần xác nhận xem `ON_THE_WAY` đã hỗ trợ chưa.
5. **Nội dung Push Notification Lock Screen**:
   - Notification tin nhắn Chat hiện đẩy toàn bộ text tin nhắn. Cần cờ cấu hình ẩn nội dung nhạy cảm trên màn hình khóa.

---

## Snapshot 2026-07-28 - Finance API update, branch state, and current handoff

### Git / Branch State

- Working branch: `NDuy`.
- Local `NDuy` is currently at commit `2c2bf4c`.
- `origin/main` is also at `2c2bf4c`, so the latest remote `main` already contains the most recent merged code currently checked out locally.
- `origin/NDuy` is **behind local `NDuy` by 5 commits**. Before testing on another machine or opening another PR from `NDuy`, run:
  - `git checkout NDuy`
  - `git push origin NDuy`
- Local `main` branch is behind `origin/main` by 5 commits. If switching to `main`, run `git checkout main` then `git pull origin main`.
- Current working tree before this handoff update was clean except Git warnings about the global ignore file permission: `C:\Users\N DUY/.config/git/ignore`.

### Latest commits on top of old `origin/NDuy`

- `62f8108` - `revert(finance): dung lai design So chi tieu theo model khai-bao-thu-nhap`
- `18c8e27` - `merge: keo main ve giap (surplus allocation, deputy task proof, contribution/fund) - giu child_wallet design cua minh`
- `696c899` - `feat(family): trao quyen Truong nhom + cap nhat API_DOCS Tuan 10`
- `847e2ab` - `chore(mobile): gom thay doi moi (polish finance/theme/screens + transfer-ownership)`
- `2c2bf4c` - `chore(finance): an child_wallet design cua minh - dung ban main (Duy) de tranh xung dot merge`

### Finance API list from BE - current FE mapping status

BE confirmed Finance prefix: `/families/:familyId/finance`.

Covered in mobile FE:

- Overview / dashboard: `/overview` legacy fallback and newer `/summary`, `/cash-flow-summary`, `/category-spending-summary`, `/member-contribution-summary`.
- Reports: `/reports/overview`, `/reports/budget-goal`, `/reports/non-essential-spending`.
- Monthly finance: `/monthly-finances/me`, `/monthly-finances/members/:memberId`, `/monthly-summary/me`, `/monthly-summary/members/:memberId`.
- Ledger: `/ledger/entries`, detail/edit/delete flow, soft delete `VOIDED` hidden from active lists.
- Categories: `/categories` CRUD, inactive categories labeled and excluded from new-create forms.
- Models/Jars: `/model-templates`, `/models`, activate model, `/jars`, patch jar.
- Budget plans: list/create/detail/edit/activate/close/cancel/report and line CRUD.
- Financial goals: list/create/detail/edit/cancel, allocations CRUD, contribution suggestions/plans/shortage and approve/reject flow.
- Alerts: list/detail/recompute/acknowledge/resolve.
- Support requests: list/create/detail/review/cancel, with Member privacy and Manager/Deputy review expectations.

Important BE updates already acknowledged:

- Swagger now has schemas + sample JSON for `/overview`, `/summary`, `/cash-flow-summary`, `/category-spending-summary`, `/member-contribution-summary`.
- Money unit is VND and response envelope is `{ success, message, data }`.
- Empty arrays should return `[]`; nullable object fields may return `null`.
- Query params include `periodStart`, `periodEnd`, `budgetPlanId`, `includeAlerts`, `includeGoals`, `includeBreakdown`.
- BE says contribution plan now only counts allocations/submissions belonging to the correct `planId`.
- BE requires ledger/support timestamps as ISO with timezone (`Z` or `+07:00`); FE sends UTC ISO where touched.
- BE says Member support request list only returns that member's own requests.
- BE says Deputy can view member monthly finance, approve/reject contribution plans, and review support requests.

### Latest Finance QA notes from user testing

Already fixed or adjusted in FE:

- Ledger delete/huy giao dich: hide `VOIDED` rows after refresh so canceled entries do not stay in active history/totals.
- Category management: inactive categories are visible with status label, sorted after active items, and not selectable in create forms.
- Budget plan detail/report: canceled plans should not show action/report like active plans; report labels localized and UUID/raw fields reduced where possible.
- Financial goal achieved state: achieved goals show completed status and progress amount such as `8.000.000 / 15.000.000`, not misleading `0 / target`.
- Contribution plan: Manager/Deputy can update monthly contribution plan after creating it; cards show planned/paid/shortage in compact UI instead of raw JSON.
- Alerts: `Acknowledge` means "Đã xem"; `Resolve` means "Đã xử lý"; recompute can recreate alerts if the underlying budget/goal condition still exists.
- Support request: Member wallet wording changed toward personal spending support, request cards are tappable, and Manager/Deputy review uses ISO timestamp.
- Monthly finance: save uses PUT/POST fallback and should keep data after leaving/re-entering the screen.
- Finance dashboard: wired newer summary APIs with fallback to old overview.

Still needs focused retest:

1. Pull/push sync first: `git push origin NDuy` if continuing from this local repo, then run app fresh.
2. Manager Ledger: create income/expense, edit, delete, refresh; deleted entry must disappear and totals must recalc.
3. Category: create, rename, deactivate; inactive category must show status and must not appear in new ledger/budget forms.
4. Budget Plan: create draft with first line, edit/add/delete line, activate, view report, cancel/close; historical closed plans may remain in report dropdown but must show status.
5. Goal Allocation: create/edit/delete allocation; if amount exceeds source transaction available amount, FE should show a friendly domain error.
6. Contribution Plan: Manager creates/updates monthly plan; Member submits; Manager/Deputy approves/rejects; shortage updates correctly.
7. Alerts: recompute after fixing source data; alert should disappear only when source condition is actually fixed.
8. Support Request: Member create/cancel/open detail; Manager/Deputy approve/reject/open detail.
9. Monthly Finance Privacy: Member saves monthly finance with visibility toggles; Manager/Deputy view member summary and private fields must be hidden/null when toggled off.

### BE questions / bugs to keep on report list

- Confirm contribution-plan retest after BE fix: old allocations must not be counted into a new monthly plan unless tied to that plan.
- Confirm all Finance summary/report endpoints document enum/nullability/400/403 cases consistently in Swagger.
- Confirm support request detail/list includes enough identity fields for FE display (`requesterMemberId`, display name, status, reviewer fields).
- Confirm profile fields `occupation`, family-facing relationship update, member role update, grant/revoke deputy permission remain missing from mobile-facing APIs unless BE has newly added them.
- Face Profile enroll still depends on BE face quality validation; if BE returns `Face image is not enrollable`, FE can only show guidance unless BE returns detailed reason codes.

---

## 🚀 Snapshot mới nhất 2026-07-23 (Phân bổ số dư mục tiêu & Deputy Task Submission & Auto Plan Approval)

### 📌 Trạng thái Git / Branch Sync
- **Nhánh local:** `NDuy` và `main` đã được merge Fast-forward đồng bộ 100%.
- **Remote:** Cả `origin/NDuy` và `origin/main` đều đã được push và đồng bộ hoàn toàn.
- **Biên dịch:** Đã fix triệt để toàn bộ lỗi import & type lookup `FamilyProvider`.

### 🛠️ Chi tiết Fixes & Cập nhật Tính năng
1. **Phân bổ số dư vào Mục tiêu tiết kiệm (Surplus Allocation - API 1 & 2):**
   - Đã tích hợp API `GET /families/:familyId/finance/financial-goals/surplus-availability` và `POST /families/:familyId/finance/financial-goals/:goalId/surplus-allocations`.
   - Tối ưu UI/UX với 2 nút hành động phân biệt rõ ràng dòng tiền:
     - `💰 Góp tiền cá nhân (Tiền túi)`: Nộp tiền mới từ cá nhân ➡️ Tăng Tổng quỹ gia đình & Tăng quỹ mục tiêu.
     - `💼 Trích từ số dư quỹ chung`: Trích tiền dư thừa tích lũy của tháng ➡️ Quỹ chung không đổi, trích số dư khả dụng sang mục tiêu.
   - Thêm Info Banner giải thích minh bạch trong từng Popup Modal.
2. **Liên kết tự động & Tự động duyệt Kế hoạch đóng góp tháng (Auto Plan Approval):**
   - Bổ sung checkbox tự động ghi nhận khoản góp cá nhân vào Kế hoạch đóng góp tháng của thành viên.
   - Nếu người thực hiện là **Manager hoặc Deputy**, hệ thống tự động gọi API `reviewContributionPlan(..., 'approve')` để **TỰ ĐỘNG DUYỆT BÀI NỘP**, ghi nhận `actualAmount` lập tức mà không bắt Manager tự duyệt lại bài của chính mình.
3. **Chức năng nộp nhiệm vụ cho Deputy / Manager (`TaskManagementScreen`):**
   - Bổ sung nút `Bắt đầu làm` & `Nộp nhiệm vụ` (kèm đính kèm ảnh minh chứng / ghi chú) ngay trong thẻ nhiệm vụ của `TaskManagementScreen` nếu công việc đó được phân công cho chính Manager / Deputy đang đăng nhập.

---

## 🚀 Snapshot 2026-07-22 (Finance, Member UI Redesign & Multi-Admin Sync)

### 📌 Trạng thái Git / Branch Sync
- **Nhánh local:** `NDuy` và `main` đã được merge Fast-forward đồng bộ 100% tại commit `936006a`.
- **Remote:** Cả `origin/NDuy` và `origin/main` đều đã được push và đang ở commit `936006a`.
- **Kiểm thử:** **81/81 unit test PASS 100%**, `flutter analyze` clean (**0 error**).

### 🛠️ Chi tiết Fixes & Cập nhật Finance (Mobile)
1. **Lỗi Tạo Danh Mục (Category Creation 502 Error):**
   - Đã bổ sung `essentialType` mặc định (`ESSENTIAL`) cho danh mục Khoản Chi và giao diện form chọn loại thiết yếu -> Loại bỏ hoàn toàn lỗi Server 502 Bad Gateway.
2. **Lỗi `entryDate không đúng định dạng` & Chọn danh mục Thu/Chi:**
   - Chuẩn hóa định dạng `entryDate` sang chuỗi ISO UTC `YYYY-MM-DDTHH:mm:ssZ` (bỏ 6 chữ số thập phân microsecond).
   - Cập nhật popup Thu/Chi dùng `watch<FinanceProvider>()` -> Mới tạo danh mục xong là dropdown tự động cập nhật ngay.
3. **Phân bổ vào Mục tiêu (Goal Allocation):**
   - Bổ sung bộ lọc bắt lỗi khi sửa số tiền phân bổ mục tiêu: hiển thị thông báo tiếng Việt rõ ràng thay vì câu văng lỗi kỹ thuật.
4. **Phân quyền & Redesign UI Trang chủ / Sổ chi tiêu Member:**
   - **Phân quyền:** Member KHÔNG có quyền xem tổng quỹ gia đình (BE trả 403, chỉ Manager/Deputy được xem).
   - **Trang chủ Member (`child_home_screen.dart`):** Đã sửa ô lối tắt 💰 hiển thị tổng quỹ chung `51,171,111 đ` thành nhãn tính năng **"Tài chính"** (đồng bộ với AI, Album, Lịch).
   - **Sổ chi tiêu Member (`child_wallet_screen.dart`):** Loại bỏ thẻ mock `Số dư hiện tại: — đ (chưa có API)` -> Thay bằng thẻ **"Còn lại có thể tiêu"** (tính từ Hạn mức cá nhân - Đã chi tiêu) vô cùng minh bạch và chuyên nghiệp.
5. **Yêu cầu hỗ trợ (Support Requests):**
   - Sửa `_statusChip` hiển thị chính xác trạng thái `CANCELED` / `CANCELLED` thành nhãn màu xám **"Đã hủy"** trên cả màn danh sách chi tiết lẫn thẻ preview ngoài màn chính.
6. **Khai báo Tài chính theo tháng (Monthly Finance):**
   - Tự động fallback giữa `POST` và `PUT` khi đã tồn tại bản ghi khai báo tháng trước đó.

### 🌐 Trạng thái Web Admin Multi-Admin Rules (`d:\Desktop\sep`)
- Gỡ bỏ hoàn toàn Modal "Đổi vai trò" (Edit Role) và không truyền `userType` trong PATCH `/admin/users/:id` (được BE kiểm soát qua script/seed).
- Tự động `disabled` nút Khóa/Mở khóa đối với chính Admin đang đăng nhập (`u.id === user?.id`) và các tài khoản `SYSTEM_ADMIN` khác (`u.userType === 'SYSTEM_ADMIN'`).

---

## Snapshot hiện tại 2026-07-22 — Finance + Face Profile QA (đọc phần này trước)

### Git / commit handoff

- Nhánh làm việc: `NDuy`.
- Working tree **chưa commit**. `git diff --check` đã pass.
- Nhóm thay đổi chức năng cần commit cùng nhau là 25 file tracked trong
  `API_DOCS.md`, `lib/` (Finance, Face Profile, Album, notification) và các
  file untracked sau:
  - `lib/providers/face_profile_provider.dart`;
  - `lib/screens/shared/face_suggestions_sheet.dart`;
  - `test/face_profile_provider_test.dart`.
- `BAO_CAO_BE_FACE_ROLE_FEATURE_2026-07-21.md` là báo cáo gửi BE, chỉ add nếu
  nhóm muốn version-control tài liệu này.
- Không add/commit `.claude/settings*.json` hoặc `.vscode/settings.json` nếu
  chưa thống nhất cấu hình dùng chung.
- Chưa chạy được full `dart format`/`flutter analyze` trong phiên này vì tiến
  trình Flutter/Android Studio đang giữ tool lâu quá timeout; đã kiểm tra diff
  tĩnh và `git diff --check`. Cần chạy CI hoặc `flutter analyze` + `flutter
  test` sau khi commit.

### Những thay đổi FE đã làm

#### Face Profile / Album

- Thêm `FaceProfileProvider`, UI thiết lập Face Profile tại member detail,
  upload từng ảnh, trạng thái enroll/enable/disable/delete và UI xem/xử lý AI
  face suggestions trong Album.
- Feature gate Face Profile/face suggestion theo subscription feature access;
  tài liệu endpoint được bổ sung vào `API_DOCS.md`.
- Đã test enroll với ảnh thật: FE gửi request đúng nhưng BE trả
  `Face image is not enrollable`. Đây là response/validation BE, không phải
  crash FE. Cần BE cung cấp tiêu chí ảnh hoặc mẫu ảnh được chấp nhận.

#### Finance — Budget, goal, alert, report

- Chuẩn hóa input tiền dùng dấu chấm (`100000` -> `100.000`) và parse an toàn
  tại các form Budget, Goal contribution, Monthly Finance và Ledger.
- Budget Plan: tạo DRAFT có dòng ngân sách đầu tiên; tạo category inline khi
  cần; thêm/sửa/xóa budget line; action activate/cancel/close hiển thị lỗi BE
  rõ ràng; report dropdown ẩn plan CANCELED, giữ CLOSED lịch sử và ưu tiên
  ACTIVE. Nút xem report không hiện ở plan đã hủy.
- Goal: sửa mapping trạng thái BE `ACHIEVED`; card/list hiển thị đúng số đã
  góp/mục tiêu, ngày `dd/MM/yyyy`, trạng thái hoàn thành và chặn góp thêm khi
  đã đạt. Detail rút từ JSON kỹ thuật xuống tiến độ dễ đọc; allocation có
  create/edit/delete.
- Goal Contribution Plan: sửa FE gửi `FamilyMember.id` (không phải `userId`),
  parse response BE bọc trong `members`, nhận status thực tế `PLANNED` và
  `PAID`, hiển thị card gọn thay JSON thô và tính thiếu hụt gọn theo plan.
- Finance Alert: làm rõ nút `Tính lại cảnh báo từ dữ liệu hiện tại`; trạng thái
  "Đã xem"/"Đã xử lý"; resolve không giả vờ thay đổi số liệu, recompute có thể
  tạo lại alert nếu điều kiện nguồn vẫn còn. Alert RESOLVED không còn ở list.
  Detail đã ẩn UUID/field kỹ thuật. Badge notification in-app/local notification
  cập nhật theo unread count (launcher badge tùy thiết bị).
- Finance Report: localize enum/ngày/số tiền, ẩn field kỹ thuật trong report
  mode và thêm mô tả nghiệp vụ cho ba tab.

#### Finance — Model, Monthly Finance, Ledger

- Finance Model: lưu 5 Jars/80-20/Custom ở lại màn hình, cập nhật banner model
  vừa áp dụng ngay, không `pop()` về tab Tôi và không để response tải cũ ghi đè
  state người dùng vừa chỉnh.
- Monthly Finance: thêm shortcut "Tài chính tháng của tôi" cho mọi role;
  format tiền và lưu/đọc lại expected income, personal expense, shared
  contribution cùng visibility.
- Ledger/Wallet: form ghi thu/chi dùng format tiền và danh mục; giao dịch gần
  đây + lịch sử hiển thị `dd/MM/yyyy HH:mm` thay ISO raw.

### Runtime test đã làm trên emulator

- Goal allocation/góp trực tiếp: tạo, sửa và xóa đã thao tác; status/progress
  cập nhật đúng (ví dụ 8.000.000 / 15.000.000 = 53%).
- Budget: tạo Draft, thêm dòng, sửa số tiền, xóa dòng, cancel plan; validation
  yêu cầu ít nhất một dòng trước activate đã hoạt động.
- Alerts: acknowledge/resolve/recompute đã test. Sau khi góp đủ mục tiêu và
  điều chỉnh budget threshold, alert tương ứng biến mất sau recompute.
- Reports: đã mở và đối chiếu Budget, Non-essential, Budget & Goal.
- Goal contribution plan: Manager confirm/update và GET list đã test; 3 member
  plan hiển thị được sau fix parser. **Chưa test** Member submit rồi
  Manager approve/reject.
- Monthly Finance: Manager lưu `20.000.000 / 7.000.000 / 1.000.000`, bật
  visibility, thoát vào lại vẫn còn đúng.
- Ledger: ghi một thu và một chi; dấu tiền/số dư cập nhật đúng. Thời gian đã
  format để dễ đọc.

### Cần test tiếp (cần đăng nhập Member)

1. Goal contribution plan: member `submit` -> Manager `approve`/`reject`.
2. Spending support request: Member create/cancel -> Manager approve/reject.
3. Monthly summary/privacy: tắt một visibility ở Member, Manager/Deputy xem
   summary phải thấy field private là null/"Riêng tư".

### Lỗi / câu hỏi cần báo BE

1. **Goal contribution plan actual bị tính sai ngữ cảnh:** Sau khi tạo plan
   tháng 7, response `GET .../contribution-plans?month=7&year=2026` gán khoản
   goal allocation cũ `8.100.000` của Manager vào `actualAmount` plan mới có
   `plannedAmount` chỉ `222.222`, status `PAID`. Xác nhận whether allocation
   lịch sử có được tính vào plan tạo sau đó hay chỉ giao dịch submit/approve
   của đúng plan mới được tính.
2. **Ledger timezone:** máy/emulator GMT+7 lúc 02:57 nhưng BE trả cùng wall
   clock với hậu tố `Z`, ví dụ `2026-07-22T02:56:26.705Z`. `Z` nghĩa UTC là sai
   ngữ nghĩa (nếu convert chuẩn sẽ lệch +7 giờ). FE đang hiển thị theo giờ local
   được người dùng nhập; BE cần trả UTC thật hoặc offset `+07:00` nhất quán.
3. **Face Profile enroll:** BE trả `Face image is not enrollable` với ảnh chân
   dung thực. Cần contract điều kiện ảnh/face quality và mã lỗi chi tiết để FE
   hướng dẫn người dùng.

---

## Snapshot hiện tại 2026-07-19 — đọc phần này trước

> Snapshot này thay thế các kết luận CI/CD trong snapshot 2026-07-18 và các
> phần lịch sử phía dưới. Không xóa lịch sử vì vẫn chứa thông tin wiring/API.

### Kết luận ngắn

- **Admin Web CI/CD: DONE.**
- **Mobile CI: DONE.**
- **Android signed release + Google Drive + QR: DONE.**
- **Bảo mật nhiều tài khoản Admin: chưa thể kết luận DONE; phải được BE enforce.**
- **iOS native/TestFlight: chưa thực hiện; iPhone dùng Web/PWA làm fallback.**

### Git và trạng thái repository

#### Mobile — `D:\Desktop\mobile-sep`

- Repository: `16-Doffy/SEP-Family-Care-Mobile`.
- `origin/main`: merge commit `5fe0708` (PR #2).
- Commit triển khai Google Drive OAuth: `18d43ae`.
- Nội dung tracked trên nhánh local `NDuy` đã được đối chiếu và giống
  `origin/main`; local chỉ thiếu merge-history commits.
- CI/CD đã được commit, push và merge vào `main`; không còn code CI/CD cần
  commit/push.
- Working tree local còn:
  - modified `AI_HANDOFF_LATEST.md`;
  - untracked `.claude/`;
  - untracked `.vscode/settings.json`.
- Chỉ commit `AI_HANDOFF_LATEST.md` sau cập nhật này. Không tự động commit
  `.claude/` hoặc `.vscode/settings.json` nếu nhóm chưa thống nhất dùng chung.

#### Admin Web — `D:\Desktop\sep`

- Repository GitHub hiện dùng: `16-Doffy/SEP-Family-Care-WEB`
  (remote cũ có thể redirect từ tên `SEP-Family-Care-Third-s`).
- `origin/main`: merge commit `15038e8` (PR #1).
- Commit CI/CD chính:
  - `25bb110` — thêm Web Admin CI/CD;
  - `2360f89` — chuyển deployment sang Vercel, bỏ VPS deployment.
- Nội dung tracked trên nhánh local `NDuy` đã được đối chiếu và giống
  `origin/main`; local chỉ thiếu merge-history commits.
- Các file untracked như `.claude/`, script Swagger và file tạm không thuộc
  CI/CD; không commit chung nếu chưa review.

### Admin Web CI/CD — DONE

- Workflow nằm tại root repository:
  `.github/workflows/web-admin.yml`.
- Monorepo dùng pnpm workspace; Admin Next.js nằm tại `apps/web`.
- GitHub Actions đã chạy thành công:
  - type-check/build shared package và Admin Web;
  - Next.js production build;
  - verify Docker build bằng `apps/web/Dockerfile`.
- GitHub Actions không SSH/VPS và không push GHCR ở phương án hiện tại.
- CD dùng Vercel Git Integration:
  - PR/branch tạo Preview deployment;
  - merge/push `main` tạo Production deployment.
- Production URL:
  `https://family-care-admin.vercel.app`.
- Vercel Environment Variables đã cấu hình cho Production/Preview:
  - `NEXT_PUBLIC_API_URL`;
  - `NEXT_PUBLIC_SOCKET_URL`;
  - `BACKEND_API_ORIGIN`.
- Các Vercel API project cũ đã disconnect khỏi Git repository. Dấu đỏ lịch sử
  trong commit/check cũ không phản ánh Web Admin CI/CD hiện tại.
- Tài liệu: `D:\Desktop\sep\docs\WEB_ADMIN_CICD.md`.

### Mobile CI — DONE

- Workflow: `.github/workflows/mobile-ci.yml`.
- Tự chạy khi `push` hoặc `pull_request`.
- Các bước chính:
  - `flutter analyze --no-fatal-infos`;
  - `flutter test`;
  - build APK debug;
  - upload build artifact.
- Run gần nhất đã kiểm tra: pass.

### Android signed release, Google Drive và QR — DONE

- Workflow: `.github/workflows/android-release.yml`.
- Có thể chạy:
  - thủ công bằng `workflow_dispatch`; hoặc
  - tự động khi push tag `v*`.
- Release keystore được giữ bên ngoài repository:
  `D:\Desktop\FamilyCare-Release-Keys\upload-keystore.jks`.
- Alias: `upload`.
- GitHub Repository Secrets đã cấu hình, chỉ ghi tên, không ghi giá trị:
  - `ANDROID_KEYSTORE_BASE64`;
  - `ANDROID_KEYSTORE_PASSWORD`;
  - `ANDROID_KEY_ALIAS`;
  - `ANDROID_KEY_PASSWORD`;
  - `GDRIVE_CLIENT_ID`;
  - `GDRIVE_CLIENT_SECRET`;
  - `GDRIVE_REFRESH_TOKEN`;
  - `GDRIVE_FOLDER_ID`.
- Google Drive dùng **OAuth cá nhân**, không còn dùng Service Account.
- Google Cloud project: `FamilyCare-Mobile-Release`.
- Google Drive API đã bật; OAuth app/client đã cấu hình.
- Folder Drive đích: `FamilyCare-APK-Releases`.
- Android Release run thành công:
  - run ID: `29675484478`;
  - source: `main` tại merge commit `5fe0708`;
  - status: Success;
  - artifacts: 2;
  - signed APK: `FamilyCare-1.0.0-3.apk`;
  - APK đã upload vào Google Drive;
  - QR tải APK đã được tạo.
- Artifact trực tiếp:
  - QR:
    `https://github.com/16-Doffy/SEP-Family-Care-Mobile/actions/runs/29675484478/artifacts/8438908227`;
  - signed APK:
    `https://github.com/16-Doffy/SEP-Family-Care-Mobile/actions/runs/29675484478/artifacts/8438906932`.
- QR hiện được upload lên GitHub Actions artifact. Nếu muốn ảnh QR cũng nằm
  trong Google Drive thì upload thủ công, hoặc bổ sung một bước upload QR vào
  workflow ở lần cải tiến sau.
- Tài liệu: `docs/RELEASE_ANDROID.md`.

### Hành vi release về sau

- Không cần cấu hình lại Google Cloud, OAuth, GitHub Secrets hoặc keystore.
- Mỗi commit/PR thông thường chỉ chạy Mobile CI; không phát hành APK để tránh
  tạo quá nhiều bản release.
- Khi cần phát hành thủ công:
  1. Actions → Android Release → Run workflow;
  2. chọn `main`;
  3. nhập version hoặc để trống để dùng version trong `pubspec.yaml`;
  4. bật `Upload APK to Google Drive and generate a QR code`;
  5. chạy workflow.
- Muốn tag release tự upload Drive, tạo Repository Variable:
  `GDRIVE_UPLOAD_ON_TAG=true`, sau đó push tag, ví dụ `v1.0.1`.
- Không tái sử dụng/version-overwrite tùy tiện. Phải backup đúng release
  keystore; mất/đổi keystore có thể làm APK mới không cập nhật đè lên bản cũ.

### Bảo mật và dữ liệu nhạy cảm

- Không commit `.jks`, `.keystore`, `android/key.properties`, `.env`, OAuth
  Client Secret, refresh/access token, mật khẩu hoặc Base64 keystore.
- GitHub Secrets/Variables là cấu hình ngoài Git; không ghi giá trị vào handoff.
- Bảo mật nhiều Admin phải do BE enforce:
  - RBAC/permission server-side cho mọi `/admin/*`;
  - không tin role do FE gửi;
  - session revocation, audit log, rate limit và MFA nếu áp dụng;
  - kiểm thử `401`/`403` và nhiều Admin độc lập.
- Checklist: `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.

### Việc còn lại/khuyến nghị

1. Quét QR bằng thiết bị Android, tải/cài APK và smoke-test login, refresh,
   role routing, Task, Finance, SOS và Profile.
2. Backup release keystore ở ít nhất hai nơi an toàn; lưu mật khẩu trong
   password manager.
3. Tùy chọn đặt `GDRIVE_UPLOAD_ON_TAG=true` nếu nhóm muốn tag release tự upload
   Drive.
4. Tùy chọn cập nhật workflow để upload cả ảnh QR lên Google Drive.
5. Nếu cần iOS native: chuẩn bị macOS/Xcode, Apple Developer, signing và
   TestFlight. APK không cài được trên iPhone; hiện dùng Web/PWA fallback.
6. Tiếp tục làm việc với BE về checklist bảo mật nhiều Admin và hợp đồng
   Notifications realtime.

### Audit API và flow FE — tiếp tục ở phiên sau

- **Mục tiêu:** audit toàn diện Mobile Flutter theo Swagger production, SRS, UC
  Flow Tracker và báo cáo đề tài; không chỉ kiểm tra tên endpoint mà phải đối
  chiếu request/response DTO, role/permission, state transition và UI flow.
- **Nguồn cần dùng:** Swagger live
  `https://api.familycare-digital.com/api/docs` (OpenAPI:
  `/api/docs-json`), cùng các tài liệu ngoài workspace:
  - `D:\Desktop\BÁO-CÁO-NEW\SU26SE032_GSU26SE042_FAMILY_CARE_DIGITAL_FAMILY_MANAGEMENT_SO_HUYNX.docx`;
  - `D:\Desktop\BÁO-CÁO-NEW\Report3_Software Requirement Specification.docx`;
  - `D:\Desktop\BÁO-CÁO-NEW\SU26SE032_FamilyCare_UC_Flow_Tracker (2).xlsx`.
  `FinalReport_Template (1).docx` là template tham khảo, không dùng làm nguồn
  nghiệp vụ chính.
- **Kết quả đã có trước khi tạm dừng:** Swagger production hiện có endpoint
  location sharing chuẩn theo family (`GET /families/{familyId}/members/locations`,
  `POST /families/{familyId}/locations`, `PATCH /families/{familyId}/members/me/location-sharing`),
  trong khi `lib/providers/gps_provider.dart` vẫn gọi các path cũ `/location/*`.
  Đây là lỗi FE cần sửa và test trong phiên audit kế tiếp; **chưa sửa/commit**.
- **Cách bàn giao:** sửa các lỗi FE xác định được và chạy analyze/test; các
  thiếu/sai contract hoặc lỗi runtime của BE phải lập danh sách gửi BE với
  endpoint, payload/response thực tế, role bị ảnh hưởng và bước tái hiện.

## Snapshot 2026-07-18 — lịch sử

### Phạm vi hệ thống

- Mobile Flutter: `D:\Desktop\mobile-sep` — Family Manager, Deputy Member,
  Family Member và Wear OS.
- Admin Web: `D:\Desktop\sep` — `SYSTEM_ADMIN`, là Git repository độc lập.
- Hai frontend dùng chung backend và Swagger:
  `https://api.familycare-digital.com/api/docs`.
- OpenAPI JSON: `https://api.familycare-digital.com/api/docs-json`.
- API base Mobile: `https://api.familycare-digital.com/api/v1`.
- Swagger là nguồn chính cho endpoint/DTO/enum; SRS và Use Case Tracker là
  nguồn nghiệp vụ. Nếu khác nhau phải xác minh với BE, không fake API.
- `FinalReport_Template (1).docx` chứa nội dung TailorStore mẫu, không phải
  nghiệp vụ FamilyCare.

### Git và CI/CD Android

- Nhánh làm việc: `NDuy`.
- Commit thêm CI/release: `9c90557`.
- Commit sửa analyzer: `be9a470`.
- Pull Request `NDuy -> main` đã chạy cả push check và pull-request check xanh.
- Workflow Android Release đã chạy thành công trên `main`, head commit
  `1e7b12a`.
- Mobile CI tự chạy khi `push` hoặc `pull_request`:
  - `flutter analyze --no-fatal-infos`
  - `flutter test`
  - build APK debug
  - upload debug artifact
- Android Release chỉ chạy thủ công hoặc khi push tag `v*`; không tự phát hành
  sau mỗi commit thông thường.
- PR còn mang theo bốn sửa chức năng có chủ đích:
  - `lib/providers/family_provider.dart`
  - `lib/providers/task_provider.dart`
  - `lib/screens/parent/reward_management_screen.dart`
  - `lib/screens/parent/task_management_screen.dart`

### Release Android đã hoàn thành

- Release keystore được tạo bên ngoài repository:
  `D:\FamilyCare-Secrets\upload-keystore.jks`.
- Alias: `upload`.
- GitHub Repository Secrets đã cấu hình:
  - `ANDROID_KEYSTORE_BASE64`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
- Không bao giờ ghi giá trị secrets, mật khẩu hoặc Base64 vào source/handoff.
- Signed APK build thành công:
  `FamilyCare-1.0.0-1.apk`.
- Artifact: `familycare-android-1.0.0`, kèm file `.sha256`.
- Run Android Release thành công: `29637020372`.
- APK chỉ cài được trên Android. iOS cần IPA + Apple signing + TestFlight,
  hoặc dùng Web/PWA làm phương án thay thế.
- Phải giữ và backup đúng keystore trên cho mọi release sau; đổi/mất keystore
  có thể khiến APK mới không cập nhật đè lên bản đã cài.

### Verification gần nhất

- Mobile CI push: pass.
- Mobile CI pull request: pass.
- Android signed release workflow: pass.
- `flutter test`: **55/55 pass**.
- Analyze: không có error/warning; còn 11 lint mức `info`.
- APK debug build: pass.
- APK signed release build: pass.
- Chưa xác nhận runtime signed APK trên thiết bị Android sau khi tải về.

### Trạng thái yêu cầu mentor

#### 1. Bảo mật khi mở rộng nhiều Admin — phụ thuộc BE

- **Chưa hoàn thành ở cấp hệ thống.** FE route guard chỉ hỗ trợ UX, không phải
  ranh giới bảo mật.
- Checklist cần gửi và thống nhất với BE nằm tại
  `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.
- BE cần:
  - cấm đăng ký công khai với `SYSTEM_ADMIN`;
  - tách `SUPER_ADMIN`/`ADMIN` hoặc permission tương đương;
  - enforce authorization trên mọi `/admin/*`, mặc định từ chối;
  - không tin role/permission do FE gửi;
  - bảo vệ Super Admin cuối cùng;
  - hỗ trợ MFA, rate limit, quản lý/thu hồi session;
  - vô hiệu session sau đổi mật khẩu, đổi role hoặc khóa tài khoản;
  - ghi audit log bất biến cho hành động nhạy cảm.
- QA cần kiểm tra `401` khi chưa đăng nhập, `403` với user không đủ quyền,
  session bị thu hồi sau khi Admin bị khóa/hạ quyền và audit actor tách biệt
  giữa nhiều Admin.

#### 3. FE setup CI/CD

- **Mobile Flutter: DONE.** CI khi push/PR đã chạy analyze, 55 tests, build
  debug APK và upload artifact; signed Android Release trên `main` đã pass.
- **Admin Web: CHƯA DONE.** Repo `D:\Desktop\sep` đã có Dockerfile/Compose
  nhưng chưa có GitHub Actions CI/CD riêng và chưa verify Docker image trên CI.
- Khi làm Admin Web CI/CD cần BE xác nhận API production URL, CORS, cookie
  domain và health-check endpoint.

#### 4. Dockerfile, APK, Google Drive, QR và iOS

- **Signed Android APK: DONE.** Đã build có chữ ký, tạo SHA-256 và upload
  GitHub Actions artifact.
- **Google Drive + QR: PARTIAL.** Workflow/code upload Drive và sinh QR đã có,
  nhưng chưa cấu hình service account/secrets và chưa chạy thử với Drive bật.
- Còn cần `GDRIVE_SERVICE_ACCOUNT_JSON`, `GDRIVE_FOLDER_ID`, tùy chọn
  `GDRIVE_UPLOAD_ON_TAG=true`, sau đó chạy release và kiểm tra link/QR thật.
- **iOS: CHƯA DONE.** APK không cài được trên iPhone. Muốn phát hành iOS cần
  macOS/Xcode, Apple Developer, signing và TestFlight; nếu chưa có thì dùng
  Web/PWA. QR cuối nên điều hướng Android tới APK và iOS tới TestFlight/PWA.
- Dockerfile không dùng để tạo APK Flutter. Dockerfile hiện liên quan chủ yếu
  tới Admin Web/deployment web.

### Notifications realtime — hợp đồng BE mới nhận 2026-07-18

- Thông tin lịch sử phía dưới nói “BE chưa có FCM/WebSocket” đã **lỗi thời**.
- BE đã cung cấp hợp đồng Socket.IO namespace `/notifications`, tự join room
  `user:<userId>` bằng access token; không có Client → Server event.
- Server events:
  - `notification:new`;
  - `notification:unread-count`;
  - `notification:error`.
- REST notification vẫn dùng để list, lấy unread count, mark read/read-all.
- FCM token theo user/device:
  - `POST /api/v1/devices/tokens`;
  - `DELETE /api/v1/devices/tokens/:token` khi logout.
- `notification:new.id != null`: notification persisted, được thêm vào list và
  badge. `id == null`: push-only, chỉ toast/banner tức thời, không thêm list và
  không tăng badge.
- CHAT hiện là push-only và FCM có thể chứa toàn bộ nội dung tin nhắn; cần chốt
  với BE/Product chính sách ẩn nội dung nhạy cảm trên lock screen.
- **FE chưa tích hợp Socket.IO/FCM theo hợp đồng mới.** Polling 15 giây trong
  snapshot lịch sử chỉ là giải pháp tạm.
- Trước khi code cần BE xác nhận:
  1. URL Socket.IO production, Socket.IO path và server version;
  2. `/devices/tokens` đã deploy production và xuất hiện trên Swagger;
  3. thống nhất payload dùng `id` hay `notificationId`;
  4. unread count là theo family hay tổng tài khoản;
  5. chiến lược REST resync sau reconnect để lấy sự kiện bị bỏ lỡ;
  6. Firebase Android config và APNs/iOS config;
  7. chính sách hiển thị nội dung CHAT trên lock screen;
  8. test account/kịch bản token hết hạn, nhiều thiết bị và bị xóa khỏi family.

### Việc còn lại, theo thứ tự

1. Cài `FamilyCare-1.0.0-1.apk` trên Android và smoke-test login, refresh,
   role routing, Task, Finance, SOS và Profile. Nếu đang cài debug APK có chữ
   ký khác, phải gỡ bản debug trước (sẽ mất dữ liệu local).
2. Backup keystore ở ít nhất hai nơi an toàn và lưu mật khẩu trong password
   manager.
3. Cấu hình Google Drive + QR:
   - tạo Google Cloud service account;
   - bật Google Drive API;
   - share folder đích cho service-account email;
   - thêm `GDRIVE_SERVICE_ACCOUNT_JSON`, `GDRIVE_FOLDER_ID`;
   - tùy chọn variable `GDRIVE_UPLOAD_ON_TAG=true`;
   - chạy Android Release với Drive upload bật.
4. Mở workspace Admin `D:\Desktop\sep` và thêm CI/CD riêng cho Next.js/Docker.
   Admin repo đã có `apps/web/Dockerfile`, `apps/api/Dockerfile`,
   `docker-compose.yml`, `docker-compose.prod.yml` nhưng chưa có GitHub Actions.
5. Gửi `docs/BE_ADMIN_SECURITY_CHECKLIST.md` cho BE. Bảo mật nhiều Admin phải
   được enforce ở backend; FE route guard không phải security boundary.
6. Gửi các câu hỏi Notifications realtime ở trên cho BE, sau đó tích hợp
   Socket.IO, REST resync và FCM token lifecycle vào Mobile.
7. Chốt phương án iOS: TestFlight nếu có Apple Developer + macOS/Xcode;
   nếu chưa có thì dùng Web/PWA cho thiết bị iPhone.

### Trạng thái local và quy tắc bàn giao

- Tài khoản/window Codex này chỉ sửa code; commit/push thực hiện ở window Git
  khác và phải báo danh sách file trước khi stage.
- Lần kiểm tra gần nhất local chỉ còn untracked `.claude/` và
  `.vscode/settings.json`; không commit nếu nhóm chưa chủ đích dùng chung.
- Sau khi main đã merge, window Git nên đồng bộ bằng:
  `git fetch origin`, `git switch main`, `git pull origin main`.
- Không commit `.jks`, `.keystore`, `android/key.properties`, `.env`, Google
  credentials hoặc bất kỳ secret nào.
- File hướng dẫn release: `docs/RELEASE_ANDROID.md`.
- Checklist BE nhiều Admin: `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.

> Phần từ “Cập nhật 2026-07-16” trở xuống là snapshot lịch sử chi tiết. Một số
> thông tin nhánh/commit trong phần lịch sử đã lỗi thời; dùng snapshot
> 2026-07-18 ở trên làm trạng thái hiện hành.

> ⚠️ IP cũ `103.110.84.66` đã BỎ hẳn — mọi tài liệu nhắc IP này đều lỗi thời.

---

## 🆕 Cập nhật 2026-07-16 (phiên hiện tại)

Sau khi FF `giap` lên `origin/main` (`93612a9`), đã tái hoà WIP + thêm cải tiến — **9 commit local, chưa push**:

- **Invite chuyển hẳn sang MÃ MỜI 8 KÝ TỰ** (main `3c5f9cb` bỏ luồng `/invitations/{token}` cũ). FE thêm **QR thật + scanner** (`qr_flutter`, `mobile_scanner`): màn Mời hiện mã + QR encode `familycare://app/join?code=`; màn Tham gia có nút "Quét mã QR" → tự điền mã → `previewInviteCode` → `requestJoinByCode`. Quyền camera đã thêm AndroidManifest.
- **Thông báo real-time (tạm, không cần BE)**: `FamilyShell` poll toàn cục **15s** (`fetchAlerts` + `fetchNotifications`), dừng khi app nền, fetch lại khi resume. **Badge số** chưa đọc trên chuông 2 home. (BE chưa có FCM/WebSocket.)
- **SOS Response Timeline**: màn chi tiết cảnh báo (icon ℹ️) dựng timeline phản hồi từ `fetchAlertDetail().responses` — header đỏ, vị trí + mini-map, node 🚨→👀/🚗/🆘/✅→✔/✖. Parse phòng thủ (schema `responses[]` chưa document).
- **Home "Trạng thái gia đình"**: `widgets/family_status_card.dart` từ `activeAlerts` (an toàn / ai đang SOS). Bản rút gọn — chưa gắn vị trí (chờ BE location).
- **Family Map**: parse vị trí phòng thủ; **fix code chết `_pins`** trong `_locateMe`; **che raw "Cannot GET /location/family"** bằng note "🚧 đang phát triển" (cờ `sharingUnavailable`); khôi phục ±accuracy pin Tôi.
- **Task**: lọc `isActive` ở picker giao việc & reassign (tránh gán nhầm member REMOVED).
- **BE đã fix (team xác nhận 07/16)**: góp mục tiêu bỏ `ledgerEntryId`, gán task theo `FamilyMember.id` + bỏ chặn role, proof URL tự sinh lại. FE vốn đã tương thích → không phải sửa thêm (trừ lọc isActive).
- **Báo cáo BE mới**: `BAO_CAO_BE_SOS_2026-07-16.md` — 3 EP location sharing (`GET /location/family`, `POST /location/update`, `PATCH /location/toggle`) + 3 điểm SOS-detail (schema `responses[]`, enum `ON_THE_WAY`, phone thành viên).
- **Model/Build**: `userType` (SYSTEM_ADMIN) tách khỏi `familyRole` (main `fc59c69`); `planCode` đổi **FREE|MONTHLY|YEARLY**; hạ AGP 9.0.1→8.11.1 + giảm gradle heap. Verify: **55/55 test pass**, analyze 0 error.
- **Kiểm chứng Swagger prod 16/07** (fetch trọn `docs-json`, so canonical với bản Tuần 9): **giống hệt 100%** (183 paths / 133 schemas) — BE chưa ship gì mới sau 15/07. Kết quả soi SOS schemas:
  - `responses[]` **ĐÃ được document** (`SosResponseResponseDto`): field chuẩn là **`responderMember`** `{displayName, familyRole, user{fullName, email, avatarUrl}}` + `responseType` + `respondedAt` + `message` → **FE đã sửa parse timeline** đưa `responderMember` lên đầu chuỗi fallback (trước đó thiếu key này → tên hiện "Thành viên").
  - `responseType` enum = `VIEWED|CONFIRM_SAFE|NEED_HELP|RESOLVED|CANCELED` — **xác nhận KHÔNG có `ON_THE_WAY`** → "Tôi đang đến" vẫn phải dựa text message (còn nợ BE).
  - `SosMemberUserResponseDto` **không có `phone`** → nút Gọi người khác vẫn chờ BE (còn nợ).
  - `status` alert có giá trị thứ 4 **`FALSE_ALARM`** — FE chưa có nhãn riêng (TODO nhỏ, hiện rơi về hiển thị raw).
  - `/location/family|toggle|update` **xác nhận không tồn tại** → Bug 1 báo cáo BE còn nguyên hiệu lực.

---

## Nguyên tắc làm việc (bắt buộc)

1. **Chỉ build trên endpoint ĐÃ TỒN TẠI trong Swagger live.** Field/response chưa rõ → đánh `[VERIFY]` hỏi Nghĩa, KHÔNG tự đoán.
2. **Giữ `API_DOCS.md` đồng bộ với code** mỗi khi wire endpoint mới.
3. **Không mock/fake call** cho tính năng BE chưa có endpoint — giữ placeholder UI.
4. Verify bằng **kịch bản thật** (chạy app đối chiếu BE) cho các luồng nhạy cảm, không chỉ tin unit test.

---

## Cấu trúc dự án (thực tế 2026-07-11)

```
lib/
├── main.dart · main_wear.dart (Wear OS entrypoint riêng — chưa có flavor build)
├── models/user.dart               (enum UserRole { manager, deputy, member } + capabilities)
├── navigation/
│   ├── app_router.dart            (go_router + computeRedirect thuần, unit-test được)
│   └── family_shell.dart          (bottom-nav shell dùng chung 3 role)
├── providers/                     (provider/ChangeNotifier)
│   ├── auth_provider.dart         family_provider.dart      invitation_provider.dart
│   ├── finance_provider.dart      finance_alert_provider.dart
│   ├── task_provider.dart         sos_provider.dart         notification_provider.dart
│   ├── wallet_provider.dart       money_provider.dart       support_request_provider.dart
│   └── gps_provider.dart          (location UI-only, BE chưa có endpoint độc lập)
├── screens/
│   ├── auth/   login · register · verify_email · forgot_password · family_setup · join_family
│   ├── parent/ (Manager/Deputy) home_dashboard · task_management · reward_management ·
│   │           wallet · finance_model · budget_plan(+detail) · financial_goal · goal_detail ·
│   │           goal_contribution · finance_reports · finance_alerts · support_request ·
│   │           subscription · member_list · invite_member · invitation_requests · calendar
│   ├── child/  (Member) child_home · child_tasks · child_wallet
│   └── shared/ profile · edit_profile · sos · notifications · chat* · album* · ai_assistant* ·
│               family_map* · payment_result · splash   (* = mock, BE chưa có endpoint)
├── services/api_client.dart       (singleton, Bearer + auto-refresh 401, unwrap {success,data})
├── theme/  app_colors.dart · app_theme.dart
├── utils/  validators.dart        (bộ Validators dùng chung — từ UI kit của main)
├── widgets/ app_input · money_input · empty_state · json_report_view · avatar_widget ·
│            ring_chart · waffle_chart · request_money_sheet
└── wear/   main_wear.dart + screens Wear OS (dùng chung provider)
```

---

## Trạng thái wiring — ĐÃ NỐI API THẬT

### Auth & Session
Login / register / logout / refresh / me — wired. Token qua `flutter_secure_storage`. `ApiClient` gắn `Bearer`, retry 1 lần khi 401 (refresh token), unwrap envelope `{ success, message, data }`.
- ✅ **Verify email OTP (BẮT BUỘC / mandatory)**: `POST /auth/verify-email {code}` + `/auth/resend-verification`. Router ép sang `/verify-email` khi `pendingEmailVerification && !hasFamily`. `POST /families` trả **403** nếu chưa verify — message thật là **tiếng Việt** ("Vui lòng xác thực tài khoản...") nên `createFamily` tin thẳng `statusCode==403` (KHÔNG check `contains('verif')` — bug đã sửa).
- ✅ **Quên mật khẩu** (2026-07-11, endpoint mới): `POST /auth/forgot-password {email}` → BE gửi OTP → `POST /auth/reset-password {email, code, newPassword}`. Màn `forgot_password_screen.dart`, link "Quên mật khẩu?" ở login.

### Role & Route
`familyRole` từ `/auth/me`: `FAMILY_MANAGER`→manager, `DEPUTY_MEMBER`→deputy, `FAMILY_MEMBER`→member. Capabilities trong `AppUser` — **hành động nhạy cảm KHÔNG dùng `isAdministrative` chung** mà tách riêng (`canInviteMembers`/`canRemoveMembers`/`canManageSubscription` chỉ Manager, đã verify BE trả 403 cho Deputy). Router guard chặn cross-shell.

### Family & Invitation — **MÃ MỜI 8 KÝ TỰ (main `3c5f9cb`, thay luồng token cũ)**
GET/PATCH `/families/{id}` (đổi tên), DELETE member (soft-delete, lọc `status==ACTIVE`). **Luồng mời mới kiểu Zalo/Discord** (`invitation_provider.dart` viết lại):
- Manager: `GET /families/{id}/invite-code` (mã hiện tại) · `POST .../invite-code/regenerate` (tạo/đổi mã, mã cũ vô hiệu ngay).
- Người xin vào: `GET /invite-codes/{code}` (preview, public) · `POST /invite-codes/{code}/join-requests` (gửi yêu cầu, chỉ cần đăng nhập, KHÔNG cần verify email) · `GET /me/join-requests` (poll trạng thái) · `POST /me/join-requests/{id}/cancel`.
- Manager duyệt: `GET /families/{id}/join-requests` · `POST .../{id}/approve` (chọn role+quan hệ) · `POST .../{id}/reject`. `InvitationRequestsScreen` (fetch 1 lần + refresh tay, chưa poll).
- Mã 8 ký tự alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (bỏ I/O/0/1). **FE thêm QR + scanner** (xem changelog 07/16). `savePendingInviteToken` giữ tên cũ nhưng giá trị nay là **mã** (không phải token).
- 🐛 Race-condition đã sửa: dialog "Đã gửi yêu cầu" refetch `refreshFamilyContext()` trước điều hướng (Manager có thể duyệt ngay lúc member còn ở dialog).
- ⚠️ **Chưa realtime** cho join-request (module notifications còn stub) → Manager phải bấm refresh; Member poll `/me/join-requests` ~12s khi mở "Yêu cầu của tôi".

### Finance (module sâu nhất — 42/42 endpoint mobile đã nối)
Overview · ledger · jars/models · categories · budget-plans (+lines +report +detail edit) · financial-goals (+detail +progress +allocations sửa/xóa) · **goal contribution plans** (suggestions/confirm/submit/approve/reject/shortage — `GoalContributionScreen`) · alerts (+detail +recompute) · monthly-finances/me · reports (planned-vs-actual, `FinanceReportsScreen`) · support-requests (+detail). Response schema chưa document → render qua `JsonReportView` generic.

### Tasks & Reward
Full CRUD task/recurring/schedule (+generate-assignments) · assignments (assign/reassign/start/cancel/detail) · submissions (+review) · proof upload · reward-setting (create/read/update/delete) · **`RewardManagementScreen`** (3 tab: Thanh toán/Tranh chấp/Báo bận). Enum reward settlement đúng BE: `PENDING_SETTLEMENT | WAITING_CONFIRMATION | SETTLED | DISPUTED | CANCELED`. Score/XP tính từ task status thật — **không có endpoint gamification**.
- Còn thiếu UI: `PATCH/DELETE tasks/proofs/{proofId}` (luồng upload+submit gộp 1 lần, chưa có bước sửa proof).

### SOS (10 operations)
Create alert · GET list/detail · respond (`responseType`) · confirm-safety · resolve/cancel (Manager/Deputy) · **push location** + `locations/batch` (buffer offline, `pushLocationBatch` — chưa nối UI) + `location/current` (`fetchCurrentLocation`, đã gọi từ `sos_screen.dart`). Location streaming mỗi 20s khi alert active.
- ⚠️ 2 nhóm enum `sourceType` KHÁC nhau: alert = `MOBILE_APP/WEARABLE/SIMULATED_DEVICE`; location = `MOBILE_GPS/WEARABLE_GPS/SIMULATED_GPS`. Không lẫn.
- ✅ **2 fix từ main (2026-07-10, verify live BE)**: id đọc từ **`sosAlertId`** (không phải `id`) → sửa bug 404 "Tôi đang đến"; GPS treo → `timeout(10s)` + `getLastKnownPosition` + chốt cứng **15s** ở `_triggerSOS` (quá 15s vẫn gửi SOS không kèm toạ độ). `SosAlert` thêm `severity`/`resolutionNote`/`resolvedByName`.

### Chat gia đình — **[MỚI, wire thật 2026-07-11]**
BE ship 18 endpoint REST `/families/{fid}/chat/conversations/...` → FE wire xong (`chat_provider.dart` 517 dòng, `chat_screen.dart` viết lại). GROUP/PRIVATE · gửi ảnh (image_picker) · reaction · ghim · sửa/thu hồi · participants · read. `ChatProvider` đăng ký trong `main.dart`. **Transport REST polling** (`startPolling`/`stopPolling`), KHÔNG phải WebSocket.
- ✅ **Tin an toàn nhanh (2026-07-13)**: nút khiên trong input bar → sheet 4 tin mẫu, gửi `messageType: SOS_QUICK_MESSAGE` tường minh; bubble cam + nhãn "TIN AN TOÀN". Verify live BE echo đúng messageType.

### Album gia đình — **[MỚI 2026-07-13, BE ship 14 EP, swagger 223 ops]**
Giáp wire 13 EP (`album_provider.dart` + `album_screen.dart` viết lại: upload, thùng rác, tag, moderation per-media, filter). NDuy gán nốt `GET /albums/moderation` — hàng đợi kiểm duyệt toàn gia đình (nút 🛡️ AppBar, duyệt nhanh MARK_SAFE/KEEP_FLAGGED, hiển thị riskScore AI). File URL là signed URL có hạn.
- **Mọi role đều dùng được album** (verify live: member GET media 200, moderation 403 đúng thiết kế). Manager: tab shell `/manager/album`. Deputy/Member: route phẳng `/album` — entry từ trang Tôi ("Album gia đình") + shortcut 🖼️ ở Trang chủ member. Màn album tự gate nút kiểm duyệt theo `isAdministrative`.

### Xem tài chính member — **[MỚI 2026-07-13, UC gap #5 BE đã đáp ứng]**
3 EP mới: `monthly-finances/members/{memberId}` + `monthly-summary/me|members/{memberId}` (đều cần `month&year`, verify live OK). `MemberFinanceScreen` (route `/manager/member-finance?memberId&name`): chọn tháng, 3 card khai báo/quỹ gia đình/mục tiêu; field private BE trả null → hiện "🔒 Riêng tư". Entry: Member List → sheet "Xem tài chính tháng" (gate `canManageFinance` — Manager/Deputy; member route bị guard chặn, member xem của mình trong ví riêng).

### Notifications
GET list · PATCH read · read-all. Tap routing theo `referenceType`. Field id thật là `notificationId`.

### Subscription
GET current · GET `/subscription-plans` · POST `/checkout {planCode}`. `planCode` chuẩn **`FREE | MONTHLY | YEARLY`** (main `359d12b` — đổi từ FREE|PLUS|PREMIUM). Nút Nâng cấp → checkout → `url_launcher` mở Stripe.
- ✅ **UX hạ gói (2026-07-13)**: CTA đổi thành "Hạ xuống {tên}" khi gói rẻ hơn gói đang dùng (so sánh `priceValue`) + dialog xác nhận trước checkout.
- ✅ **Hết nháy FREE (main `627b2c4`)**: `_currentPlan` nullable = đang tải → hiện spinner, khoá checkout khi chưa biết gói (trước bị nháy FREE 2–3s).
- ⚠️ `[VERIFY]` response `/checkout` **vẫn trống schema** trong Swagger — FE hiện chỉ đọc `data['checkoutUrl']` (chưa fallback `url`/`sessionId`). Hỏi Nghĩa field thật + luồng chọn FREE (downgrade?).

---

## Backend Gaps — KHÔNG fake call

Swagger live vẫn **0 endpoint** cho (Chat & Album nay đã CÓ — xem các mục trên):
- **AI assistant**, **Calendar events** (`/events`), **FCM token** push (→ đang poll tạm ở `FamilyShell`)
- **Location sharing độc lập** ngoài SOS (chỉ có toạ độ trong ngữ cảnh 1 alert) → **đã có báo cáo chính thức `BAO_CAO_BE_SOS_2026-07-16.md`**; FE che raw 404 bằng note "đang phát triển".
- **PATCH /auth/me** (sửa profile), **role management user-facing** (UC18)
- **Wearable pairing / SOS device settings**
- ⚠️ **SOS alert detail** thiếu document `responses[]` + enum "đang đến" + phone thành viên (3 câu trong báo cáo trên).

25 endpoint `/admin/*` mới (audit-logs, backups, docker infra, revenue, provisioning...) thuộc **Admin Web**, ngoài phạm vi FE Mobile.

---

## `[VERIFY]` đang chờ Nghĩa

1. **[Payment]** `POST /subscription/checkout` trả field nào để redirect Stripe (`checkoutUrl`/`url`/`sessionId`)? Chọn FREE là downgrade riêng hay cũng qua `/checkout`?
2. **[Chat]** Transport hiện là REST polling — BE có kế hoạch chuyển WebSocket realtime không? Giới hạn `limit` khi load lịch sử, encode emoji trong URL reaction.
3. **[RESOLVED 2026-07-29 — Finance model / fund allocation]** BE đã đổi khóa
   chống trùng thành `familyId + periodMonth + periodYear`; đổi model không cho
   chia lại cùng kỳ. POST/GET history đã trả `createdAt`,
   `createdByMemberId`, `note`, sort mới nhất trước và giữ item legacy nullable.
   FE đã wire contract, xử lý 409, test mapping và kiểm tra runtime thành công.

---

## Verification (2026-07-16)

`flutter test` → **55/55 pass** · `flutter analyze lib` → **0 error** (11 info-lint pre-existing/từ main). Build APK debug OK (Gradle 9.1.0 / AGP 8.11.1 / Kotlin 2.3.20).
Test phủ: router redirect (verify mandatory), auth/role capabilities (+2 test mới từ main), register error mapping, SOS provider parse/guard. **Chưa verify runtime** (cần device): SOS Timeline khi có `responses[]` thật; badge/poll thông báo; quét QR mã mời.
- ⚠️ Windows build: cần **bật Developer Mode** (symlink cho plugin); nếu build lỗi lạ (BuildConfig exists / Dart compiler exited) → `flutter clean` (kill dart/java nếu `.dart_tool` bị khoá).

---

## Nhánh & Git

`giap` đã **FF tới `origin/main` (`93612a9`)** rồi chồng **9 commit local** (invite QR-code, poll+badge, map fix, SOS timeline, Home status, task isActive, map 404, build-config, docs). **Chưa push** (origin/giap còn ở `cb050e9`). Backup: `giap-backup-before-ff-20260715` (@cb050e9), `giap-backup-before-ff-20260711`, `giap-backup-20260710`.

## Next Suggested Work

1. ~~Push~~ ✅ **Đã push** `giap` + merge FF vào `main` và push `origin/main` (16/07).
2. Gửi `BAO_CAO_BE_SOS_2026-07-16.md` cho Nghĩa — còn nợ BE: **location 3 EP** (Bug 1) + **enum `ON_THE_WAY`** + **`phone` trong `SosMemberUserResponseDto`**. Kèm câu hỏi: fix gán task có áp cho `generate-assignments` (định kỳ) chưa.
3. **Verify runtime trên device**: quét QR mã mời (2 máy), badge/poll thông báo, SOS Timeline với alert có phản hồi thật (tên phải hiện đúng sau fix `responderMember`), block "Trạng thái gia đình".
4. Khi BE ship location: đổi path `GpsProvider` (parse đã sẵn) → mở marker nhiều thành viên + family cards có vị trí.
5. TODO nhỏ: nhãn hiển thị cho status **`FALSE_ALARM`** (detail sheet + alert card đang rơi về raw).
6. `[VERIFY]` tồn đọng: checkout field Stripe, chat WebSocket.
