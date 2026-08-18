# Đề xuất BE — Thực thi `featureAccess` theo gói ở tầng server

Ngày: **2026-08-18** · Người soạn: FE Mobile + Admin Web (nhánh `NDuy`)
Trạng thái: **mức Bắt buộc** — không phải tối ưu trải nghiệm, mà là lỗ hổng
sản phẩm: gói Miễn phí hiện dùng được đầy đủ tính năng của gói trả phí nếu gọi
thẳng API, bỏ qua app.

---

## Bối cảnh

Hệ thống có 26 key `featureAccess` chính thức (khai trong `CreateSubscriptionPlanDto`
Swagger), dùng để phân biệt gói Miễn phí / Gói tháng / Gói năm. Admin Web đã có
UI cấu hình đầy đủ 26 key cho từng gói, và cả Admin Web lẫn Mobile đều **đọc và
hiển thị đúng** quyền lợi từng gói ở màn Gói dịch vụ / Gói đăng ký.

Vấn đề: rà lại toàn bộ endpoint có gọi kiểm tra quyền theo gói
(`assertFeatureEnabled` — pattern đang dùng cho nhóm lịch), chỉ thấy đúng
**1 nhóm trong 26 key** có kiểm tra thật ở server. 23 key còn lại **không bị
chặn ở đâu cả** — kể cả khi FE đã ẩn/khoá UI, người dùng vẫn gọi thẳng API
(Postman, app khác, hoặc sau này có bên thứ 3 tích hợp) để dùng được tính năng
gói cao hơn mà không cần trả tiền.

## Đối chiếu — key nào đã chặn, key nào chưa

| Nhóm | Key | Chặn ở server? |
|---|---|---|
| Lịch | `calendar.enabled`, `calendar.reminders`, `calendar.recurringEvents` | ✅ Có |
| Tài chính | `finance.budgetPlanning`, `financialGoals`, `budgetAlerts`, `supportRequests`, `reportExport`, `aiOcrSuggestion` | ❌ Không |
| Nhiệm vụ & thưởng | `tasks.recurringTasks`, `proofUpload`, `rewardSettlement`, `rewardAllocation` | ❌ Không |
| Album | `album.videoUpload`, `faceSuggestions` | ❌ Không (FE chỉ khoá UI) |
| Trợ lý AI | `ai.assistant`, `financeSummary`, `taskSummary`, `savingSuggestions` | ❌ Không (FE chỉ khoá UI cho `ai.assistant`) |
| SOS | `sos.wearablePairing`, `fallDetection`, `liveLocation`, `routeHistory` | ❌ Không |
| Nhắn tin | `chat.privateChat`, `attachments`, `announcements` | ❌ Không |

**Kết quả thật đang xảy ra**: tài khoản gói Miễn phí đọc báo cáo tài chính
nâng cao, tạo nhiệm vụ lặp lại, ghép thiết bị đeo, dùng Trợ lý AI... đầy đủ —
không khác gì tài khoản đã trả tiền, chỉ cần bỏ qua app và gọi thẳng endpoint.

## Đề xuất

Áp dụng đúng pattern đã có sẵn cho lịch (`plan-limits.service.ts` →
`assertFeatureEnabled(familyId, key)`), thêm vào các service tương ứng:

| Service cần sửa | Key cần thêm |
|---|---|
| `finance.service.ts` | `finance.budgetPlanning`, `financialGoals`, `budgetAlerts`, `supportRequests`, `reportExport` |
| `task.service.ts` | `tasks.recurringTasks`, `rewardSettlement`, `rewardAllocation` |
| `album.service.ts` | `album.videoUpload`, `faceSuggestions` |
| `ai-chat.service.ts` | `ai.assistant` (đủ — 3 key con `financeSummary/taskSummary/savingSuggestions` không cần chặn riêng, xem ghi chú dưới) |
| `sos.service.ts` | `sos.wearablePairing`, `fallDetection`, `routeHistory` (**không chặn** `sos.liveLocation` — xem lưu ý an toàn) |
| `chat.service.ts` | `chat.attachments` (xem lưu ý dưới) |

Trả lỗi có `code: "FEATURE_LOCKED"` kèm `featureKey` trong body 403, để FE
phân biệt được "bị khoá vì gói" với "bị khoá vì role" hay lỗi khác, hiện đúng
màn mời nâng cấp thay vì banner lỗi chung chung.

## Hai lưu ý quan trọng — xin BE đọc kỹ trước khi làm

1. **Không chặn `sos.liveLocation` và thao tác gửi SOS thủ công.** Đây là
   tính năng an toàn, không nên khoá theo gói dù Admin có thể bật/tắt được ở
   UI — đề nghị BE bỏ qua enforcement cho riêng key này (hoặc để BE chốt lại
   nếu có lý do khác).
2. **`ai.financeSummary` / `ai.taskSummary` / `ai.savingSuggestions` không
   phải endpoint riêng** — đây là 3 hành vi bên trong Trợ lý AI (một
   conversation, nhiều loại câu hỏi), không tách được thành route riêng để
   gate độc lập. Chỉ cần chặn `ai.assistant` ở cổng vào — đã đủ, không cần
   BE cố tách 3 key con này thành enforcement riêng.
3. **`chat.privateChat` khả năng không chặn được** — chat nhóm cơ bản là
   tính năng nền tảng mọi gia đình cần có, không nằm trong phạm vi khoá theo
   gói. Xin BE xác nhận lại ý định ban đầu của key này trước khi quyết định
   có enforcement hay để nguyên (ẩn khỏi danh sách cấu hình nếu xác nhận
   không dùng).

## Không cần BE làm gì thêm cho các mục sau (đã xử lý ở FE)

- Admin Web: đã ẩn khỏi hộp thoại cấu hình 5 key thật sự "chưa có gì đứng
  sau" (`finance.aiOcrSuggestion`, `ai.financeSummary/taskSummary/
  savingSuggestions`, `chat.announcements`) để tránh admin bật nhầm bán thứ
  chưa tồn tại. Nếu BE sau này xây thật `finance.aiOcrSuggestion` (quét hoá
  đơn AI) thì báo lại, FE mở khoá tick ngay (đổi 1 dòng cấu hình).
- FE (cả Admin Web và Mobile) đã đồng bộ tên hiển thị 26 key giống nhau giữa
  hai nền tảng — không phải việc của BE.
