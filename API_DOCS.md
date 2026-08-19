# API Backend Analysis — Family Care
**Server:** https://api.familycare-digital.com/api/v1
**Swagger UI:** https://api.familycare-digital.com/api/docs
**Date:** snapshot 2026-07-07 (118 paths) → **re-verify 2026-07-28 bằng `familycare-swagger-2026-07-28.json`**. FE wiring audit lại sau khi đồng bộ `origin/main` tại `e5aa216`.

> ### 🔄 Cập nhật API mới (2026-08-11 **đợt 2**) — **237 paths / 304 operations / 273 schemas**
> BE trả lời hết `CAU_HOI_BE_VIDEO_CALL_2026-08-11.md` và ship thêm ngay trong ngày. So với đợt 1
> cùng ngày (`236/303/262`):
> - **`GET /calls/{callId}`** — endpoint mới, phục hồi trạng thái sau khi socket reconnect.
> - **11 schema Calls** (`CallResponseDto`, `InitiateCallResponseDto`, `JoinCallResponseDto`,
>   `CallActionResponseDto`, `CallHistoryResponseDto`, `CallStatus`, `CallParticipantStatus`...) —
>   trước đó **cả 6 endpoint đều không có response schema**, chỉ mỗi `InitiateCallDto`.
> - **11 mã lỗi ổn định** khai đủ trong Swagger (`CALL_ALREADY_ACTIVE`, `LIVEKIT_NOT_CONFIGURED`...).
> - `NotificationResponseDto.referenceType` **bổ sung `'CALL'`** (nay 12 giá trị) — chỗ Swagger tự
>   mâu thuẫn ở đợt 1 (enum `NotificationType` có `CALL` mà `referenceType` không có) đã được sửa.
>
> **Bug thật do bộ câu hỏi phát hiện:** cuộc gọi không ai bắt máy trước đây nằm `RINGING` vô thời hạn
> và **khoá luôn hội thoại** không gọi lại được. BE đã thêm timeout 30 giây tự chuyển `MISSED`.
>
> FE đã cập nhật `call_provider.dart` theo schema chính thức — **không còn `[VERIFY]` nào** cho module này.
>
> ### 📌 BE trả lời bộ câu hỏi đối chiếu contract (2026-08-09) — xem `CAU_HOI_BE_2026-08-09.md`
> Bộ câu hỏi này **chỉ để đối chiếu**, không yêu cầu BE đổi gì. Kết quả: phần lớn FE đã hiểu đúng, gỡ được nhiều `[VERIFY]` treo lâu.
>
> **Đã chốt, FE không phải sửa gì:** `type == 'SOS'` khớp enum `NotificationType`; icon thông báo phủ đủ 9 giá trị; `referenceId` mapping đúng; `requesterMember.user.fullName` FE đoán **đúng**; BE tự map category → hũ khi không gửi `jarId` (đúng cách FE đang làm); logout có gửi `refreshToken` nên phiên đồng hồ sống sót; Google login tự liên kết email sẵn có.
>
> **BE ship thêm cùng ngày:** `PATCH /families/{familyId}/members/{userId}/relationship` (trước đây chọn nhầm quan hệ là kẹt vĩnh viễn); notification cho luồng hỗ trợ chi tiêu; enum `NotificationType`/`NotificationPriority` vào Swagger.
>
> **FE đã làm ngay:** thêm `case 'SUPPORT_REQUEST'` vào `NotificationRouter` + `test/support_request_notification_test.dart`; wire `PATCH .../relationship` + `test/member_relationship_test.dart`.
>
> **Dump đã cập nhật (đợt 2 cùng ngày):** `230 paths / 297 operations / 261 schemas` — thêm endpoint `relationship`, `UpdateMemberRelationshipDto`, và 7 schema Notification (`NotificationType`, `NotificationPriority`, `NotificationResponseDto`, 3 envelope + `NotificationUnreadCountResponseDto`). `referenceType` nay là **enum 11 giá trị** trong Swagger, đã gồm `SUPPORT_REQUEST`.
>
> **Còn treo:** 4 mã lỗi `claim` trên màn đồng hồ; nhắc chọn danh mục khi AI tạo giao dịch thiếu `categoryId`. Phía BE còn nợ response schema cho `/auth/login`, `/auth/firebase`, `/auth/me` và support-request (Notification đã xong).
>
> **Bỏ hẳn, không chờ nữa:** `summary.spending.byJar` (đã có `reports/jar-target-actual`); upload avatar (BE không có endpoint).

> ### 🔄 Cập nhật API mới (2026-08-09) — **229 paths / 296 operations / 253 schemas**
> Export lại từ Swagger `https://api.familycare-digital.com/api/docs-json` trong A4. So với bản 226 paths, BE bổ sung **3 path AI Sprint 2/3**:
> - `GET /families/{familyId}/ai-chatbot/daily-brief`
> - `POST /families/{familyId}/ai-chatbot/conversations/{conversationId}/messages/{messageId}/actions/{actionIndex}/confirm`
> - `POST /families/{familyId}/ai-chatbot/conversations/{conversationId}/messages/{messageId}/actions/{actionIndex}/reject`
>
> FE đã wire cả 3 endpoint mới: `AiChatbotProvider.fetchDailyBrief`, `confirmStep`, `rejectStep`. `AiActionType` chính thức hiện có 9 giá trị: `CREATE_LEDGER_ENTRY`, `CREATE_BUDGET_PLAN`, `CREATE_BUDGET_LINE`, `CREATE_FINANCIAL_GOAL`, `CREATE_GOAL_ALLOCATION`, `CREATE_GOAL_CONTRIBUTION_PLAN`, `ALLOCATE_FUND_BY_MODEL`, `CREATE_TASK`, `CREATE_CALENDAR_EVENT`.

> ### 🔄 Cập nhật API mới (2026-08-07) — **226 paths / 293 operations / 248 schemas**
> So với bản `223 paths / 290 operations / 245 schemas`, BE đã bổ sung **Wearable Activation**:
> - `POST /wearable-activations`: Wear OS tạo `sessionId` bí mật và `code` công khai `FCW-XXXXXX`.
> - `GET /wearable-activations/{sessionId}`: Wear OS poll trạng thái `PENDING | PAIRED | CLAIMED | EXPIRED`.
> - `POST /wearable-activations/{sessionId}/claim`: Wear OS claim `accessToken`, `refreshToken`, `user` sau khi mobile pair mã.
>
> Bản ngay trước đó cũng đã bổ sung **25 response/schema**:
> - **AI Chatbot**: có DTO chính thức cho conversations, messages, send message, confirm/reject action, delete conversation; enum `AiActionType` đã mở rộng lên 9 giá trị trong Swagger 2026-08-09 và `AiActionStatus` (`PENDING | CONFIRMED | REJECTED | EXPIRED`).
> - **Wearable sensor event**: `POST /families/{familyId}/wearables/{deviceId}/events` có `WearableEventIngestApiResponseDto`, gồm `event`, `alertCreated`, `alertId`; duplicate active SOS trả `alertCreated=false` và `alertId` là SOS active hiện có.
> - **Wearable error codes** đã được document trong response lỗi: `WEARABLE_ALREADY_PAIRED`, `DEVICE_IDENTIFIER_TAKEN`, `WEARABLE_NOT_PAIRED`, `INVALID_SENSOR_EVENT_TYPE`, `INVALID_SENSOR_EVENT_PAYLOAD`.

> ### 🔄 Cập nhật Tuần 10 (2026-07-23) — swagger **216 paths / 281 operations**
> Kể từ snapshot 07/11 (147 paths), BE đã ship nhiều module; FE đã wire phần lớn:
> - **Calendar** (5): events CRUD + `respond` + `reminder` — ✅ wire.
> - **AI Chatbot** (5): conversations + messages + `confirm/reject-action` (pendingAction) — ✅ wire.
> - **Album** (13) + moderation/tags/face-suggestions + **Face Profiles** (5: validate/enroll/enable/disable/delete) — ✅ wire.
> - **Wearables** (3), **Devices/FCM tokens** (2), **`POST /auth/firebase`** (đăng nhập Google) — ✅ wire.
> - **Finance analytics** (4): `/finance/summary`, `/cash-flow-summary`, `/category-spending-summary`, `/member-contribution-summary` — ✅ wire (Duy).
> - **Ledger entry** `/finance/ledger/entries/{entryId}` GET/PATCH/DELETE (sửa/void) + `DELETE /finance/categories/{categoryId}` — ✅ wire.
> - **Monthly finance** `/finance/monthly-finances/me` + `/members/{memberId}`; `/finance/monthly-summary/me` + `/members/{memberId}` — ✅ wire.
> - **Goal surplus** 🆕: `GET /finance/financial-goals/surplus-availability`, `POST /finance/financial-goals/{goalId}/surplus-allocations` — ✅ wire (Duy, `goal_detail_screen`).
> - 🆕 **`POST /families/{familyId}/transfer-ownership`** `{ targetUserId, confirm }` — Trao quyền Trưởng nhóm (FAMILY_MANAGER only) — ✅ wire (`member_detail_screen`, 2026-07-23).
>
> **Chưa có:** `GET /finance/monthly-finances/me/history` (biểu đồ member đang loop từng tháng). `PATCH /auth/me` và `PATCH /families/{familyId}/members/{userId}/role` đã có trong Swagger 28/07 và đã wire FE.
> **Cần verify hành vi BE (không thấy trong DTO):** duyệt support-request có tự trừ quỹ + bump `expectedPersonalExpense`? Income có tự vào quỹ?

> ⚠️ **Swagger 07/11 vs 07/07 — +29 path**:
> - **+25 path `/admin/*`** (audit-logs, backups, docker infra, revenue, provisioning, restores, system health...) → **Admin Web, NGOÀI phạm vi FE Mobile**.
> - **+4 path mobile**: `POST /auth/forgot-password`, `POST /auth/reset-password`, `GET .../sos/.../location/current`, `POST .../sos/.../locations/batch` — **cả 4 đã wire FE** (qua commit main `d80eacf` + phần SOS trước đó).
>
> ⚠️ **Các thay đổi lớn trước đó** (đã wire hết):
> 1. Invitation flow **claim → approve** (bỏ `/accept`).
> 2. Subscription checkout Stripe (`[VERIFY]` field response — xem mục Subscription).
> 3. Notifications 3 endpoint (bỏ mock; chưa có FCM token).
> 4. Email verification (`verify-email`/`resend-verification`) — luồng **MANDATORY**.
> 5. Finance mở rộng: Goal Contribution Plan + reports planned-vs-actual.
>
> **Cập nhật 2026-07-11 (sau fast-forward lên `origin/main` 6621248):** BE đã ship **module Chat (18 endpoint REST)** —
> FE đã wire (`chat_provider.dart`, xem mục Chat bên dưới). SOS thêm 2 fix (`sosAlertId`, GPS treo).
>
> Dòng lịch sử “0 endpoint” trước đây đã hết hiệu lực: Swagger 28/07 đã có location sharing, `PATCH /auth/me`, đổi role Phó nhóm, Calendar, AI Chatbot và device/notification APIs; source Mobile hiện đã wire các nhóm này. Vẫn chưa có endpoint family-facing để sửa `relationship`/nghề nghiệp.

---

## Endpoints

### Auth
- `POST /api/v1/auth/register` — Register a new account (default role: FAMILY_MANAGER). 409 nếu email đã tồn tại.
- `POST /api/v1/auth/login` — Authenticate with email & password. 401 sai thông tin, 403 account bị khóa.
- `POST /api/v1/auth/refresh` — Rotate token pair bằng refresh token hợp lệ.
- `POST /api/v1/auth/logout` — Log out. Có `refreshToken` **hợp lệ** → revoke đúng device đó; bỏ trống **hoặc token invalid** → revoke tất cả (BE xác nhận 09/08).
  - ⚠️ Hệ quả cho Wear OS: `auth_provider.dart` có gửi `refreshToken` nên đăng xuất trên điện thoại **không** giết phiên của đồng hồ. Nhưng nếu token đã xoay vòng và bản lưu bị cũ thì rơi vào nhánh "invalid → revoke all" và đồng hồ chết im.
- `POST /api/v1/auth/firebase` — **[CHỐT BE 2026-08-09]** Đăng nhập Google. Body `FirebaseLoginDto { idToken }`.
  - Email đã tồn tại **và** Google token có `email_verified=true` → BE **tự liên kết** `firebaseUid` vào user cũ rồi trả token bình thường. **Không** tạo user trùng email, **không** trả 409 (`AuthService.loginWithFirebase`).
  - Response 200 giống `/auth/login`: `accessToken`, `refreshToken`, `user`.
  - Trạng thái đã liên kết Google lưu ở **`User.firebaseUid`**; không có bảng `auth_providers`.
  - `401` = idToken sai/hết hạn. `503` = server thiếu hoặc sai `FIREBASE_SERVICE_ACCOUNT` — hai cái này phải hiện hai câu khác nhau.
- `GET /api/v1/auth/me` — Lấy user đang đăng nhập.
- `PATCH /api/v1/auth/me` — **[wire FE 2026-07-28]** cập nhật `fullName`, `phone`. `avatarUrl` nhận string/null nhưng **BE không có endpoint upload avatar** (xác nhận 09/08; hai endpoint upload duy nhất là task proof và chat attachment). FE cố ý không hiện ô sửa avatar cho tới khi có luồng upload.
- `POST /api/v1/auth/verify-email` — **[MỚI, đã wire FE 2026-07-07]** Verify email bằng OTP 6 số. Body `VerifyEmailDto { code }`. 400 nếu OTP sai/hết hạn. Xem `VerifyEmailScreen` + `AuthProvider.verifyEmail()`.
- `POST /api/v1/auth/resend-verification` — **[MỚI, đã wire FE 2026-07-07]** Gửi lại OTP (rate-limited). 400 nếu đã verify hoặc đang cooldown. Xem `AuthProvider.resendVerificationCode()`.
- `POST /api/v1/auth/forgot-password` — **[MỚI 07/11, đã wire FE]** Body `ForgotPasswordDto { email }`. BE gửi OTP 6 số qua email. Xem `forgot_password_screen.dart` bước 1.
- `POST /api/v1/auth/reset-password` — **[MỚI 07/11, đã wire FE]** Body `ResetPasswordDto { email, code, newPassword }` (`code` = OTP 6 số; `newPassword` ≥8 ký tự, đủ hoa/thường/số/ký tự đặc biệt). Xem `forgot_password_screen.dart` bước 2 + link "Quên mật khẩu?" ở login.

### Families
- `POST /api/v1/families` — Tạo family (creator thành MANAGER). **403 nếu account chưa verify** (verify email
  **BẮT BUỘC** trước khi tạo family — luồng mandatory, router tự đẩy sang `/verify-email`). Verify bằng
  kịch bản thật 2026-07-08: message thật trả về là **tiếng Việt** `"Vui lòng xác thực tài khoản để dùng chức
  năng này"` — KHÔNG chứa từ "verify"/"verif" như Swagger mô tả ("Account not verified"). FE từng check
  `e.message.contains('verif')` để phát hiện case này → không bao giờ khớp → `pendingEmailVerification` không
  được set → router không redirect sang `/verify-email` → **luồng bắt buộc xác thực hỏng** (user kẹt ở
  family-setup với snackbar lỗi). Đã sửa: `AuthProvider.createFamily()` tin thẳng `statusCode == 403` vì đây
  là lý do 403 duy nhất được document cho endpoint này.
- `GET /api/v1/families/my` — Danh sách family user thuộc về.
- `GET /api/v1/families/{familyId}` — Lấy family (members only). 403 nếu không phải member.
- `PATCH /api/v1/families/{familyId}` — Update family (MANAGER only). **[wire FE 2026-07-08]** nút ✏️ cạnh tên gia đình trong `member_list_screen.dart` (chỉ Manager thấy).
- `DELETE /api/v1/families/{familyId}/members/{userId}` — Xóa member (MANAGER only). 400 không xóa được manager.
- `PATCH /api/v1/families/{familyId}/members/{userId}/role` — **[wire FE 2026-07-28]** Manager bổ nhiệm/gỡ Phó nhóm bằng `familyRole: DEPUTY_MEMBER | FAMILY_MEMBER`.
- `PATCH /api/v1/families/{familyId}/members/{userId}/relationship` — **[BE ship + FE wire 2026-08-09]** Sửa quan hệ gia đình của 1 thành viên. Trước đây không có cách nào sửa sau khi đã duyệt vào nhà: chọn nhầm lúc approve join request là kẹt vĩnh viễn, chỉ SYSTEM_ADMIN gỡ được.
  - Body `UpdateMemberRelationshipDto { relationship }`; enum: `FATHER | MOTHER | SPOUSE | CHILD | SISTER | BROTHER | GRANDPARENT | OTHER`.
  - **MANAGER only** — Swagger ghi rõ `403 Requires family MANAGER role`. FE gate bằng `canManageMemberRoles`, **không** dùng `isAdministrative` (Deputy sẽ ăn 403).
  - **Ràng buộc BE:** mỗi family chỉ **1 `FATHER`** và **1 `MOTHER`**; `GRANDPARENT` và các quan hệ còn lại cho phép nhiều.

  | Mã | Ý nghĩa | `code`/`errorCode` |
  |---|---|---|
  | `400` | `relationship` không hợp lệ | — |
  | `403` | Không phải Manager | — |
  | `404` | Không tìm thấy member trong family | — |
  | `409` | Đã có Bố | `FAMILY_ALREADY_HAS_FATHER` |
  | `409` | Đã có Mẹ | `FAMILY_ALREADY_HAS_MOTHER` |

  - **FE (`member_detail_screen.dart`):** card "Quan hệ gia đình" chỉ hiện với Manager và member `ACTIVE`, **kể cả chính Manager** — chọn nhầm xảy ra ngay từ lúc tạo gia đình chứ không riêng lúc duyệt. Dialog chặn trước lựa chọn `FATHER`/`MOTHER` đã có người giữ (kèm tên) để người dùng hiểu lý do, nhưng vẫn bắt 409 vì BE mới là nguồn sự thật. Bắt theo `code`, không theo `message`.
  - ⚠️ **Chỉ 8 giá trị trên được gửi lên.** `FamilyMember.relationLabel` còn dịch được `PARENT`/`SIBLING` cho dữ liệu cũ, nhưng hai giá trị đó **không** có trong dialog — gửi lên sẽ ăn `400`. Giá trị cũ hiển thị kèm chữ "(giá trị cũ)".
  - Ghim bằng `test/member_relationship_test.dart` (11 case).

### SOS (10 operations — khớp `sos_provider.dart`; +2 endpoint mới 07/11)
- `POST /api/v1/families/{familyId}/sos/alerts` — Kích hoạt SOS (mọi thành viên). Body `CreateSosAlertDto { sourceType, triggerReason?, severity?, initialLatitude?, initialLongitude?, message? }`.
  - `sourceType`: `MOBILE_APP | WEARABLE | SIMULATED_DEVICE` (default `MOBILE_APP`)
  - `triggerReason`: **[MỚI 2026-08-18, BE đã xác nhận contract]** `MANUAL | FALL_DETECTION` (default `MANUAL` nếu không truyền — FE luôn truyền tường minh). `FALL_DETECTION` KHÔNG bị chặn bởi `locationRequired` dù thiếu `initialLatitude/initialLongitude` — thiếu GPS vẫn trả `201 Created`, không phải `400` (BE đã implement rule này, xem `BAO_CAO_BE_FALL_DETECTION_BACKGROUND_2026-08-18.md`); các `triggerReason` khác vẫn bị chặn như cũ khi family bật `locationRequired`. **[VERIFY môi trường]** BE cần deploy migration + server rule này lên môi trường FE test trước — nếu test trên môi trường chưa deploy, case thiếu GPS vẫn có thể gặp `400` theo rule cũ.
  - `severity`: `LOW | MEDIUM | HIGH | CRITICAL`
- `GET /api/v1/families/{familyId}/sos/alerts` — Lịch sử SOS. Query `status`: `ACTIVE | RESOLVED | CANCELED | FALSE_ALARM`.
- `GET /api/v1/families/{familyId}/sos/alerts/{alertId}` — Chi tiết 1 alert (kèm phản hồi + vị trí). **[wire FE 2026-07-08]** icon ℹ️ trên alert card → `_SosAlertDetailSheet` (`JsonReportView`).
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/locations` — Gửi 1 điểm vị trí cho alert active. Body `PushSosLocationDto { latitude, longitude, sourceType, accuracy?, recordedAt?, deviceId? }`. **[wire FE 2026-07-07]** `SOSScreen._startLocationStreaming()` — gọi mỗi 20s từ lúc gửi SOS thành công tới khi confirm-safety.
  - `sourceType`: `MOBILE_GPS | WEARABLE_GPS | SIMULATED_GPS`
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/locations/batch` — **[MỚI 07/11]** Gửi NHIỀU điểm 1 lần. Body `PushSosLocationBatchDto { points: PushSosLocationDto[] }`. **[wire FE 2026-08-11]** `SosProvider.pushLocationBatch()` trả `bool` (như `pushLocation`) — `SOSScreen._startLocationStreaming()` buffer điểm gửi lỗi vào `_pendingLocationPoints` (cap 50), flush bằng batch ở lần `pushLocation` thành công kế tiếp; buffer xoá khi flush OK hoặc khi dừng stream.
- `GET /api/v1/families/{familyId}/sos/alerts/{alertId}/location/current` — **[MỚI 07/11]** Vị trí MỚI NHẤT của alert. **[wire FE]** `SosProvider.fetchCurrentLocation()` → gọi từ `sos_screen.dart` để đặt pin ban đầu khi mở màn theo dõi.
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/responses` — Phản hồi. Body `CreateSosResponseDto { responseType, message? }`.
  - `responseType`: chỉ chấp nhận `VIEWED | CONFIRM_SAFE | NEED_HELP` từ thành viên (enum còn có `RESOLVED | CANCELED` nhưng không dùng qua route này).
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/confirm-safety` — Người kích hoạt tự xác nhận an toàn.
- `PATCH /api/v1/families/{familyId}/sos/alerts/{alertId}/resolve` — Resolve (FAMILY_MANAGER / DEPUTY_MEMBER). Body `ResolveSosAlertDto { resolutionNote? }`.
- `PATCH /api/v1/families/{familyId}/sos/alerts/{alertId}/cancel` — Cancel (FAMILY_MANAGER / DEPUTY_MEMBER). Body `ResolveSosAlertDto { resolutionNote? }`.

> ⚠️ SOS location chỉ gửi được **trong ngữ cảnh 1 alert đang active** (`.../alerts/{alertId}/locations`). Vẫn KHÔNG có location tracking độc lập ngoài SOS.
> ⚠️ **Response parse (fix main 2026-07-10, verify live)**: BE trả id ở field **`sosAlertId`** (KHÔNG phải `id`) → `sendSos()` đọc `created['sosAlertId'] ?? created['id']` (thiếu → bug 404 "Tôi đang đến"). Người gửi ở `triggeredByMember.user.fullName` (nested); toạ độ trả **STRING**; list alert đọc thêm key `items`. `SosAlert` có thêm `severity`/`resolutionNote`/`resolvedByName`.

### Chat gia đình — **[MỚI 2026-07-11, BE ship + FE wire, 18 endpoint REST]**
Base: `/api/v1/families/{familyId}/chat/...` · provider `chat_provider.dart` · **transport REST polling** (không phải WebSocket).
- `GET /chat/conversations` · `POST /chat/conversations` (type `GROUP | PRIVATE`)
- `GET/PATCH /chat/conversations/{cid}` (đổi tên / archive) · `POST .../leave`
- `POST /chat/conversations/{cid}/participants` · `DELETE .../participants/{memberId}`
- `GET /chat/conversations/{cid}/messages?limit=50` · `GET .../pinned-messages`
- `POST /chat/conversations/{cid}/messages` (gửi tin) · `POST .../messages/upload` (ảnh/file)
- `PATCH /chat/conversations/{cid}/messages/{id}` (sửa) · `DELETE .../messages/{id}` (thu hồi)
- `POST .../messages/{id}/reactions` · `DELETE .../messages/{id}/reactions/{emoji}`
- `POST .../messages/{id}/pin` · `DELETE .../messages/{id}/pin`
- `POST /chat/conversations/{cid}/read` (đánh dấu đã đọc)
- `messageType`: `TEXT | IMAGE | FILE | LOCATION | SOS_QUICK_MESSAGE | CALL` — **`CALL` là giá trị mới (Swagger 11/08)**, BE bắn kèm khi cuộc gọi kết thúc để log "Cuộc gọi video · 5:32" trong khung chat; loại tin này **không cho** sửa/thả cảm xúc/ghim (BE trả 400). `[VERIFY]` giới hạn `limit`, encode emoji URL, có nên chuyển WS realtime.
- ✅ **Tin an toàn nhanh (2026-07-13, verify live)**: FE gửi `messageType: SOS_QUICK_MESSAGE` tường minh trong `SendMessageDto` — nút khiên cạnh ô nhập chat mở sheet 4 tin mẫu, bubble hiển thị nổi bật màu cam kèm nhãn "TIN AN TOÀN". BE echo đúng `messageType` trong response (đã test server thật).

### Calls — gọi video qua LiveKit **[BE ship 2026-08-10, FE đang wire theo giai đoạn]**
Provider `call_provider.dart` · media đi thẳng client ↔ **LiveKit Cloud**, BE chỉ ký token + phát tín hiệu.

> ⚠️ **KHÁC MỌI MODULE KHÁC: endpoint là top-level `/api/v1/calls/...`, KHÔNG nằm dưới `/families/{familyId}`.**
> **Tuyệt đối không dùng `ApiClient.familyPath()`** — BE tự suy family/quyền từ `conversationId`/`callId`; điều kiện
> duy nhất là người gọi đang là participant còn hoạt động của hội thoại. Ghép nhầm prefix là silent fail.

> ✅ **Chốt contract 2026-08-11 (đợt 2)** — Swagger nay khai **đủ cả 7 endpoint** (thêm `GET /calls/{callId}`), 11 schema
> (`CallResponseDto`, `InitiateCallResponseDto`, `JoinCallResponseDto`, `CallActionResponseDto`, `CallHistoryResponseDto`,
> `CallStatus`, `CallParticipantStatus`...) và 11 mã lỗi. **Không còn `[VERIFY]` nào treo cho module này.**
> Nguồn: `CAU_HOI_BE_VIDEO_CALL_2026-08-11.md` + `CALLS_GUIDE.md`/`CALLS_QA.md` của BE.

- `POST /api/v1/calls` — khởi tạo. Body `InitiateCallDto { conversationId }` → `InitiateCallResponseDto { callId, roomName, token, livekitUrl, call }`.
  Trả vé vào phòng ngay, **không chờ ai bắt máy**. `callId` ngoài cùng và `call.id` luôn cùng giá trị.
- `POST /api/v1/calls/{callId}/join` — bắt máy → `JoinCallResponseDto { callId, roomName, token, livekitUrl }` (**không** kèm `call`).
- `POST /api/v1/calls/{callId}/decline` · `.../leave` · `.../end` — cả 3 trả `CallActionResponseDto { callId, status }`, `status` là trạng thái **sau** thao tác.
  - `leave` **chỉ báo BE**; rời phòng media là `room.disconnect()` phía LiveKit — 2 việc độc lập, phải gọi cả hai.
  - ⚠️ **Người khởi tạo gọi `leave` lúc còn `RINGING` → BE trả `CANCELED`**, tương đương `end`. Không cần bắt UI chọn đúng hàm.
  - `end` chỉ người khởi tạo (403 `NOT_INITIATOR`); trả `ENDED` nếu đã có người vào phòng, `CANCELED` nếu chưa ai kết nối.
- `GET /api/v1/calls/conversations/{conversationId}?cursor=&limit=` — lịch sử → `CallHistoryResponseDto { items, nextCursor }`.
  `nextCursor` **luôn có field**, `null` khi hết trang.
- `GET /api/v1/calls/{callId}` — **[MỚI đợt 2]** lấy 1 cuộc gọi theo id, đúng cho việc phục hồi trạng thái sau khi socket `/chat` reconnect.
  Trước đó phải lách qua `conversations/{cid}?limit=1`. → `CallProvider.getCall()`.

**Envelope:** có, `TransformInterceptor` global (`main.ts:48`), **không ngoại lệ** cho `/calls/*` → `ApiClient` bóc `data` như mọi module khác.

**Enum (đã có trong `components.schemas`, FE vẫn giữ chuỗi gốc thay vì enum Dart cứng — bài học `referenceType`):**
- `CallStatus`: `RINGING | ONGOING | ENDED | MISSED | DECLINED | CANCELED`.
  ⚠️ **`MISSED` nay ĐÃ hoạt động**: BE có job timeout **30 giây** kể từ `POST /calls`, không ai bắt máy thì tự chuyển `MISSED`
  và **giải phóng hội thoại**. *Trước đợt 2, cuộc gọi nằm `RINGING` vô thời hạn và khoá luôn hội thoại — bug thật, FE hỏi mới lộ ra.*
- `CallParticipantStatus`: `INVITED | JOINED | DECLINED | LEFT | NO_ANSWER` — **`NO_ANSWER` vẫn chưa bao giờ được set**
  (timeout xử lý ở cấp cả cuộc gọi, chưa đánh dấu riêng từng người). Đừng làm UI cho trạng thái này.
- `endedReason`: `hangup | timeout | all_left | declined` — **chữ thường**, khác hẳn mọi enum khác viết HOA.

**11 mã lỗi ổn định** (`CallErrorCode` trong `call_provider.dart`) — **bắt theo `code`, KHÔNG theo `message`**:
| `code` | HTTP | Endpoint |
|---|---|---|
| `CALL_ALREADY_ACTIVE` · `CONVERSATION_ARCHIVED` · `CONVERSATION_TOO_FEW_MEMBERS` | 400 | `POST /calls` |
| `CALL_ALREADY_ENDED` | 400 | `.../join` |
| `NOT_FAMILY_MEMBER` | 403 | `POST /calls`, `GET` (cả 2) |
| `NOT_INVITED` | 403 | `.../join`, `.../decline` |
| `NOT_IN_CALL` | 403 | `.../leave` |
| `NOT_INITIATOR` | 403 | `.../end` |
| `CALL_NOT_FOUND` | 404 | mọi endpoint có `:callId` |
| `CONVERSATION_NOT_FOUND` | 404 | `POST /calls`, `GET .../conversations/:id` |
| `LIVEKIT_NOT_CONFIGURED` | 503 | `POST /calls`, `.../join` — lỗi **cấu hình server**, không gợi ý người dùng thử lại |

**Signaling đi nhờ namespace Socket.IO `/chat`** (room `conversation:<id>`), không có namespace riêng: `call:incoming`,
`call:accepted`, `call:declined`, `call:participant-update`, `call:ended`, kèm `chat:message:new` loại `CALL`.
Không có event client→server nào cho call; mọi hành động đi qua REST ở trên.
- **Vào room: client tự `emit('chat:join', { workspaceId })`** — ⚠️ field tên **`workspaceId`**, KHÔNG phải `conversationId`/`familyId`.
  **Join 1 lần là đủ cho MỌI hội thoại** trong family; không cần đang mở màn chat nào để nhận `call:incoming`.
- `participants` trong `call:incoming` là mảng **object đầy đủ**, không phải mảng `memberId`.
- `/chat` là namespace chat **đầy đủ** (tin nhắn, typing, presence, reaction, pin...), không riêng cho call →
  **sau này bỏ được REST polling của `chat_provider.dart`**, nhưng đó là thay đổi lớn, để sau đợt bảo vệ.
- ✅ **[GĐ2 xong 2026-08-11]** `lib/services/chat_socket_service.dart` — transport Socket.IO cho `/chat`,
  viết theo đúng khuôn `NotificationSocketService` (tự quản reconnect/backoff để mỗi lần thử lại đọc token mới nhất).
  Nghe đủ 5 event `call:*` + `chat:message:new`; models `CallIncomingEvent`/`CallParticipantUpdateEvent`/`CallEndedEvent`
  ở `call_provider.dart`, có test khoá contract (`test/call_socket_event_test.dart`).
- ⚠️ `chat_provider.dart` vẫn **REST polling 5 giây/lần**. Bỏ polling để dùng hẳn `/chat` là thay đổi lớn,
  cố ý để **sau đợt bảo vệ**.

**Giai đoạn 3 — kết nối phòng LiveKit:**
- ✅ **[3a xong 11/08]** `livekit_client: ^2.11.0` + quyền `RECORD_AUDIO`/`MODIFY_AUDIO_SETTINGS`/`BLUETOOTH_CONNECT`.
  Đã build + cài lên máy thật, mở app qua nhiều màn hình không crash — rủi ro của việc thêm 19 package native
  (gồm `flutter_webrtc`) đã kiểm chứng trực tiếp.
- ✅ **[3b xong 11/08]** `lib/services/livekit_room_service.dart` — singleton quản lý vòng đời `Room`
  (`connect`/`disconnect`/bật-tắt camera-mic). Không bọc thêm tầng trừu tượng quanh `Room`/`RoomEvent`:
  nơi gọi tự `room.createListener()` (đã expose qua `.events`) rồi `.on<T>()` theo đúng API gốc LiveKit.
  `connect()` tự dọn phòng cũ trước — không bao giờ để tồn tại 2 phòng cùng lúc.
- ✅ **[3c xong 12/08]** `lib/screens/shared/incoming_call_screen.dart` (Từ chối/Nghe) và
  `active_call_screen.dart` (video người kia phủ kín màn qua `VideoTrackRenderer`, video mình khung nhỏ
  cố định góc trên-phải, mic/camera/kết thúc).
- ✅ **[Group call FE xong 12/08]** BE không chặn `GROUP` nên FE đã mở nút gọi cho cả hội thoại nhóm
  đang active, truyền metadata participant vào `ActiveCallScreen`, đổi remote track sang map theo
  `participant.identity = memberId`, và render grid cho gọi nhóm. 1-1 vẫn giữ layout cũ; group không tự
  đóng màn chỉ vì một participant rời phòng, chỉ đóng khi phòng không còn remote participant/có `call:ended`.
  Chưa có invite thêm người trong lúc gọi, chia sẻ màn hình, ghi hình hoặc chat trong cuộc gọi.
- ✅ **[3d xong 12/08]** `CallProvider` đăng ký vào cây provider ở `main.dart`; `startRealtime()`/`stopRealtime()`
  nối `ChatSocketService` theo đúng khuôn `NotificationProvider`. `family_shell.dart` gọi `startRealtime()`
  lúc mở app (sống suốt phiên như `/notifications`), `call:incoming` → mở `IncomingCallScreen` — **tự lọc bỏ
  cuộc gọi của chính mình** bằng cách so `initiatedByMemberId` với `participants[].member.userId` (workspace
  join theo cả gia đình nên người gọi cũng nhận lại event của chính mình, không có field nào đánh dấu sẵn).
  `call:ended` phát qua `CallProvider.lastEndedCallId` (tín hiệu một-lần, không phải state bền) — cả
  `IncomingCallScreen` lẫn `ActiveCallScreen` tự đóng khi khớp `callId`, bắt được cả case người kia từ chối
  **trước khi từng vào phòng LiveKit** (lúc đó không có `RoomEvent` nào báo, chỉ socket mới biết).
- **Giới hạn đã chốt:** cuộc gọi **chưa chạy nền** (tắt màn hình/bấm Home giữa cuộc gọi sẽ rớt). Cần
  foreground service + `FOREGROUND_SERVICE_MICROPHONE`/`CAMERA` (Android 14+), gom vào cùng đợt foreground
  service của tính năng SOS (nhánh `sos-shake`) để không viết hai lần. **Đủ 4 giai đoạn (GĐ1–4) — còn lại
  chỉ là giới hạn nền này.**
- **Giới hạn KHÁC, đo được 12/08 trên máy Oppo + emulator thật — cuộc gọi ĐẾN khi app đang nền —
  ✅ BE ĐÃ GỠ CHỐT 12/08 (đợt 3):** `IncomingCallScreen` trước đó chỉ tự mở khi app đang **foreground**
  với socket `/chat` đang sống (`family_shell.dart._onIncomingCall`, xem 3d); app backgrounded thì
  `call:incoming` không tới được Flutter, chỉ có notification FCM thường, không tự mở màn nào. FE đã
  nối tap `referenceType=CALL` → `/incoming-call/:token?callId=...` → `GET /calls/{callId}` → dựng
  `IncomingCallScreen` nếu call còn live (12/08), nhưng phần tự bung full-screen khi app nền vẫn
  chặn ở việc BE gửi FCM dạng `notification` message.
  **BE xác nhận đã đổi (đợt 3, 12/08):** push "cuộc gọi đến" (`referenceType=CALL`, lúc `initiate()`)
  nay là **data-only message** (không có khối `notification`, Android không tự vẽ) — thiết kế opt-in
  qua field `dataOnly` trong `EphemeralNotificationInput`, chỉ `CallsService.initiate()` bật, không
  ảnh hưởng `referenceType` khác. Cấu trúc `data` nhận được, xem mục "Push" bên dưới.
  ⚠️ **Chỉ có hiệu lực trên Android** — iOS cần VoIP Push (PushKit), cơ chế khác hẳn, ngoài phạm vi.
  ✅ **13/08 — Đã code + đã sửa lỗi + đã xác nhận hoạt động đúng bằng cuộc gọi thật lúc máy đang
  KHOÁ MÀN HÌNH** (`local_notification_service.dart` + `push_service.dart`, dùng
  `flutter_local_notifications` thay vì Kotlin/MethodChannel — lý do kỹ thuật + toàn bộ diễn biến
  debug xem `KE_HOACH_VIDEO_CALL_NHOM_VA_CUOC_GOI_DEN_NEN_2026-08-12.md` mục 9–10). Lỗi ban đầu:
  `LocalNotificationService.init()` gọi `requestNotificationsPermission()` cần Activity, nhưng
  `firebaseBackgroundHandler` chạy trong isolate nền không có Activity → ném exception chặn
  `_plugin.show()` không bao giờ chạy tới — đã sửa bằng try/catch. **Còn thiếu:** test ca app bị
  kill hẳn (không chỉ backgrounded), test trên máy Oppo/ColorOS thật (mọi test 13/08 đều trên
  emulator), nút Từ chối trên màn full-screen-intent bấm không phản ứng lúc test (chưa rõ bug thật
  hay do thao tác emulator) — xem checklist đầy đủ ở mục 10.4 file kế hoạch.

**LiveKit:** `participant.identity` = **`memberId`** (KHÔNG phải `userId`). Token **TTL 10 phút**, dùng lại được để reconnect
trong 10 phút, không bắt buộc gọi `join` lần nữa. `livekitUrl` cố định toàn hệ thống (ENV `LIVEKIT_URL`).
Đa thiết bị cùng `identity`: BE **không chặn**, theo mặc định LiveKit thiết bị vào sau đá thiết bị cũ.

**Push:** `referenceType = "CALL"` (Swagger đã bổ sung vào `NotificationResponseDto`, nay 12 giá trị), `referenceId = callId`.
Gửi cho mọi participant trừ người gọi, đúng 1 lần lúc khởi tạo. Khi timeout `MISSED`, người **chưa từng bắt máy** nhận thêm
1 push riêng. Các case kết thúc khác (`ENDED`/`CANCELED`/`DECLINED`) **không** có push riêng.

**✅ Xác nhận BE 12/08 (đợt 3) — 2 loại push CALL khác nhau về cách gửi, phân biệt bằng `callEventType`:**

- **`callEventType: "incoming"`** (lúc `initiate()`) — **data-only message** (không có khối `notification`,
  Android không tự vẽ, FE toàn quyền dựng full-screen-intent qua `firebaseBackgroundHandler`). Khối `data`:
  ```json
  {
    "referenceType": "CALL", "referenceId": "<callId>", "callId": "<callId>",
    "conversationId": "<conversationId>", "callerName": "<tên người gọi>",
    "conversationType": "PRIVATE hoặc GROUP", "conversationName": "<rỗng nếu PRIVATE>",
    "callEventType": "incoming", "title": "<tên người gọi>", "body": "Cuộc gọi video đến",
    "notificationId": "", "type": "CALL", "familyId": "<familyId>"
  }
  ```
- **`callEventType: "missed"`** ("Cuộc gọi nhỡ", lúc timeout `MISSED`) — **vẫn là notification message
  bình thường** (Android tự vẽ, không cần full-screen-intent) — cố ý giữ nguyên vì đây chỉ là thông báo
  thông tin, không cần hành động ngay. Khối `data` tương tự nhưng không có `callerName`:
  ```json
  {
    "referenceType": "CALL", "referenceId": "<callId>", "callId": "<callId>",
    "conversationId": "<conversationId>", "conversationType": "PRIVATE hoặc GROUP",
    "conversationName": "<tên hội thoại>", "callEventType": "missed",
    "title": "<tên người gọi>", "body": "Cuộc gọi nhỡ"
  }
  ```
- Nguồn: `CAU_HOI_BE_VIDEO_CALL_NHOM_VA_PUSH_2026-08-12.md` (đã có trả lời đầy đủ) + `CALLS_GUIDE.md` mục 6 của BE.
  **FE chưa code phần dựng full-screen-intent từ payload này** — xem giới hạn "cuộc gọi ĐẾN khi app đang nền" ở trên.

**Message log:** `messageType: CALL`, `relatedCallId` là field **top-level** trên Message (schema chat chưa khai nên chưa thấy
trong Swagger). Chuỗi tóm tắt ("Cuộc gọi video · 5:32") **do BE sinh sẵn** trong `content` — FE hiển thị thẳng, không tự tính.
Loại tin này **không cho** sửa/thả cảm xúc/ghim (BE trả 400) → UI phải ẩn các nút đó.

**Gọi nhóm:** BE **không chặn** hội thoại `GROUP`; timeout 30 giây áp dụng như nhau cho cả 1-1 lẫn nhóm. FE đã mở
nút gọi nhóm và render grid nhiều participant. Phần còn thiếu là UX nâng cao (`NO_ANSWER` riêng từng người,
invite thêm người trong lúc gọi), không phải bug chặn.
**✅ Xác nhận BE 12/08:** `initiate()` chỉ check `>= 2` người hoạt động, **không có giới hạn cứng** số người tối
đa trong code BE — giới hạn thực tế (nếu có) tới từ gói LiveKit Cloud đang dùng, không phải BE tự đặt.
`GET /calls/{callId}` dùng chung `callInclude` với `POST /calls` nên `participants[]` **đầy đủ y hệt**, không
rút gọn theo số người — FE dùng đúng giả định này ở `IncomingCallEntryScreen`.

### Notifications — **[CHỐT BE 2026-08-09: đủ contract, hết đoán]**
- `GET /api/v1/families/{familyId}/notifications` — Danh sách thông báo của thành viên hiện tại. Query `unreadOnly` (bool).
- `GET /api/v1/families/{familyId}/notifications/unread-count` — Số chưa đọc.
- `PATCH /api/v1/families/{familyId}/notifications/read-all` — Đánh dấu tất cả đã đọc.
- `PATCH /api/v1/families/{familyId}/notifications/{notificationId}/read` — Đánh dấu 1 thông báo đã đọc.
- `POST /api/v1/devices/tokens` / `DELETE /api/v1/devices/tokens/{token}` — Đăng ký / gỡ FCM token. **Push notification ĐÃ hoạt động** (`PushService` gọi sau login, gỡ khi logout).

**Field của 1 notification** (BE xác nhận 09/08, `notifications.service.ts` + `notifications.types.ts`):
`id`, `familyId`, `recipientMemberId`, `type`, `priority`, `title`, `body`, `referenceType`, `referenceId`, `isRead`, `readAt`, `createdAt`.

**`type` — enum `NotificationType`** (**10 giá trị**, `CALL` thêm 11/08): `SOS | GENERAL | ALBUM_TAG | JOIN_REQUEST | MEMBER | TASK | CALENDAR | FINANCE | CHAT | CALL`.
FE dùng `type == 'SOS'` để bật banner đỏ toàn cục (`family_shell.dart`) và đẩy push mức ưu tiên cao (`push_service.dart`) — **đã verify khớp**. Bảng icon ở `notifications_screen.dart` phủ đủ **10** giá trị (`CALL` → `videocam_outlined`).

**`priority` — enum `NotificationPriority`** (4 giá trị): `LOW | NORMAL | HIGH | CRITICAL`.
⚠️ **Không có `MEDIUM`.** `AppNotification.fromJson` từng mặc định `'MEDIUM'`; `accentColor` bắt cả `'MEDIUM' || 'NORMAL'` nên không vỡ, nhưng mặc định đúng phải là `'NORMAL'`.

**`referenceType` — string tự do, KHÔNG phải enum** (`Notification.referenceType` trong `prisma/schema.prisma`).
Nghĩa là BE thêm giá trị mới bất cứ lúc nào mà không có gì báo cho FE. `NotificationRouter` cố ý fail-open: giá trị lạ → `null` → thông báo nằm im ở danh sách, không crash. **Thêm giá trị mới thì phải thêm `case` bằng tay.**

| `referenceType` | `referenceId` trỏ tới | Màn đích FE |
|---|---|---|
| `SOS_ALERT` | `SosAlert.id` | `/{shell}/sos` |
| `ALBUM_MEDIA` | `AlbumMedia.id` | `/{shell}/album` |
| `JOIN_REQUEST` | `JoinRequest.id` | `/manager/invite-requests` (Manager/Deputy) |
| `FAMILY` | `Family.id` | `/{shell}/home` |
| `FAMILY_MEMBER` | `FamilyMember.id` | `/manager/member/{id}` — `member_detail_screen` nhận **cả** `member.id` lẫn `member.userId` nên không lệ thuộc BE trả id nào |
| `TASK_ASSIGNMENT` | `TaskAssignment.id` | `/{shell}/tasks` |
| `CALENDAR_EVENT` | `CalendarEvent.id` | `/{shell}/calendar` (mọi role) |
| `BUDGET_ALERT` | `BudgetAlert.id` | `/manager/finance-alerts` (Manager/Deputy) |
| `FINANCIAL_GOAL` | `FinancialGoal.id` | `/manager/goal-detail?goalId={id}` |
| `CONVERSATION` | `Conversation.id` | `/{shell}/chat` |
| `SUPPORT_REQUEST` **[MỚI 09/08]** | `SpendingSupportRequest.id` | `/finance/support-requests` — **mọi role**, vì người nhận kết quả duyệt là chính requester (thường là Member) |
| `CALL` **[MỚI 11/08]** | `Call.id` | `/{shell}/chat` — **mọi role**. ⚠️ **Tạm thời**: màn hình cuộc gọi chưa xây (GĐ3), mở chat vì dòng tóm tắt cuộc gọi (`messageType: CALL`) nằm sẵn trong hội thoại. Có màn gọi rồi thì đổi sang mở thẳng cuộc gọi kèm `callId` |
| `null` | — | không điều hướng |

**Payload FCM** (`fcm-notification.channel.ts`) — phần `data` gồm: `title`, `body`, `notificationId`, `type`, `familyId`, `referenceType`, `referenceId`.
⚠️ Khác REST ở chỗ id tên là **`notificationId`** chứ không phải `id`. `AppNotification.fromJson` đã đọc `json['notificationId'] ?? json['id']` nên dùng chung được cho cả hai nguồn.

### Subscriptions — **[MỚI, checkout thật]**
- `GET /api/v1/families/{familyId}/subscription` — Xem gói hiện tại của gia đình.
- `POST /api/v1/families/{familyId}/subscription/checkout` — Tạo liên kết thanh toán Stripe để nâng gói. Body `CreateCheckoutDto { planCode }`.
  - ⚠️ **planCode ĐỔI LẦN 2 (phát hiện 2026-07-13 tối, verify live)**: `/subscription-plans` giờ trả `FREE | MONTHLY | YEARLY` (Gói miễn phí 0đ/3 người, Gói tháng annualPrice 180k/10 người, Gói năm 2tr/10 người) — KHÔNG còn `PLUS`/`PREMIUM`. FE render + checkout theo planCode BE trả nên không vỡ; fallback cứng trong `subscription_screen.dart` đã lỗi thời (chỉ dùng khi API chết). Ngữ nghĩa `annualPrice` của Gói THÁNG cần hỏi BE (180k là giá năm hay 15k×12?).
  - ✅ ĐÍNH CHÍNH (user confirm 13/07 tối): KHÔNG có chuyện subscription bị mất — `GET /subscription` vẫn trả đúng gói. "Tụt về FREE" là do FE mặc định `_currentPlan = 'FREE'` trong lúc chờ fetch (nháy 2-3s) → đã fix: `_currentPlan` nullable, hiện "Đang tải..." + spinner, khoá checkout khi chưa biết gói hiện tại.
  - ✅ BE confirm: `annualPrice` của Gói tháng = **giá theo NĂM** (180k/năm) — hiển thị "/năm" của FE đúng.
  - `[VERIFY]` Response schema (field `checkoutUrl` / `url` / `sessionId`?) — spec không mô tả body response. Xác nhận với Nghĩa.
  - `[VERIFY]` Luồng chọn FREE (downgrade/cancel) có gọi endpoint này không.
  - ✅ **UX hạ gói (2026-07-13)**: FE so sánh `priceValue` (annualPrice) với gói đang dùng — gói rẻ hơn hiển thị CTA "Hạ xuống {tên gói}" + dialog xác nhận trước khi checkout (thay vì "Nâng cấp Free" gây hiểu lầm). Hành vi backend khi checkout FREE vẫn chờ `[VERIFY]` ở trên.

### Finance — Monthly Finance (cá nhân)
- `GET /api/v1/families/{familyId}/finance/monthly-finances/me` — Tài chính tháng của bản thân. **Query `month` & `year` BẮT BUỘC.**
- `POST /api/v1/families/{familyId}/finance/monthly-finances/me` — Tạo. Body `CreateMemberMonthlyFinanceDto`. 409 nếu tháng đã tồn tại.
- `PUT /api/v1/families/{familyId}/finance/monthly-finances/me` — Cập nhật. Body `UpdateMemberMonthlyFinanceDto`. 404 nếu chưa khai báo.
  - DTO có thêm `expectedSharedContribution` / `actualSharedContribution` (nullable), `incomeVisibility` / `expenseVisibility` (`PRIVATE | FAMILY`).
- **[MỚI 2026-07-13, verify live]** `GET .../finance/monthly-finances/members/{memberId}?month&year` — Manager/Deputy xem khai báo của member (UC gap #5 đã xin BE 11/07). Field private BE trả `null` sẵn; member chưa khai báo → `data: null`. Wire: `FinanceProvider.fetchMemberMonthlyFinance`.
- **[MỚI 2026-07-13, verify live]** `GET .../finance/monthly-summary/me?month&year` và `GET .../finance/monthly-summary/members/{memberId}?month&year` — tổng quan tháng: `{period, member, monthlyFinance, familyFundContribution {plannedAmount, declaredActualAmount, ledgerActualAmount, actualAmount}, goalContributions {totalPlannedAmount, totalActualAmount, totalShortageAmount, items[]}}`. Số trả dạng **number thật** (khác các EP finance cũ trả string) — FE vẫn parse phòng thủ. Wire: `fetchMonthlySummaryMe` / `fetchMemberMonthlySummary` + màn `MemberFinanceScreen` (route `/manager/member-finance`, entry từ Member List, gate `canManageFinance`).

### Album gia đình — **[MỚI 2026-07-13, BE ship 14 EP + FE wire (13 EP bởi giap, queue bởi NDuy)]**
Base: `/api/v1/families/{familyId}/albums/...` · provider `album_provider.dart` · màn `album_screen.dart`.
- `GET/POST /albums/media` (list phân trang `{items, meta}` + upload multipart) · `GET/PATCH/DELETE /albums/media/{mediaId}` (detail / sửa caption+visibilityScope / xóa mềm kèm `reason`)
- `DELETE .../permanent` (body `{confirmation: 'PERMANENT_DELETE'}`) · `POST .../restore`
- `GET/POST .../tags` · `DELETE .../tags/{tagId}` (tag thành viên vào media)
- `GET/PATCH .../moderation` (xem/duyệt tay: `ManualModerationReviewDto {decision: MARK_SAFE | KEEP_FLAGGED, reviewNote}` — cả 2 field bắt buộc) · `POST .../moderation/retry`
- `GET /albums/moderation` — **hàng đợi kiểm duyệt toàn gia đình** (Manager/Deputy), item kèm `latestModeration {resultStatus, riskScore, summary}` (AI heuristic) + `fileAccess {url}` (signed URL hết hạn). Wire: `fetchModerationQueue` + sheet 🛡️ trên AppBar Album.
- File URL là **signed URL có hạn** (`expiresInSeconds`) — không cache lâu.
- **[MỚI 2026-07-27, wire FE] Face Profile validate:** `POST /face-profiles/{memberId}/validate` là multipart field `files` (3–5 ảnh). FE đọc `canEnroll` và `results[]/reasonCode`, chỉ cho đăng ký khi `canEnroll=true`. Nếu validate trả `404/405/501`, FE khóa enroll và yêu cầu thử lại sau (fail closed đúng contract mới). Swagger hiện chưa có response DTO/schema cho validate; mapping 4 reason code dùng theo hợp đồng BE đã gửi trực tiếp.
- **[MỚI 2026-07-21, wire FE] Face Profile:** `POST /face-profiles/{memberId}/enroll` là multipart field `files` (Swagger bắt buộc **3–5** ảnh) + `consentConfirmed=true`; `GET /face-profiles/{memberId}` lấy trạng thái; `PATCH .../disable|enable`; `DELETE ...` body `{confirmation: 'DELETE_FACE_PROFILE'}`. UI: Member Detail → Face Profile.
- **[MỚI 2026-07-21, wire FE] Face Suggestion:** `POST /albums/media/{mediaId}/face-scan {force?}`; `GET .../face-suggestions`; `POST .../{suggestionId}/confirm|reject`. Tag chỉ được tạo qua `confirm`; manual tag độc lập. `album.faceSuggestions` được gate theo subscription khi BE trả featureAccess đầy đủ.
- **[SỬA 2026-07-28] Face suggestion luôn cần người dùng xác nhận:** FE không tự gọi `confirm` theo confidence. AI chỉ hiển thị gợi ý; chỉ nút **Xác nhận** của người dùng mới tạo tag chính thức, đúng flow nghiệp vụ đã chốt.
- **[MỚI 2026-07-30] Nhiều khuôn mặt trong một ảnh:** Swagger live đã có `FaceSuggestionsApiResponseDto` và example `data.faces[]`, mỗi face có candidates riêng. FE vẫn hỗ trợ thêm response phẳng để tương thích dữ liệu cũ, giữ ứng viên điểm cao nhất **theo từng face**, hiển thị confidence và yêu cầu user xác nhận trước khi tạo tag.
- **[SỬA 2026-08-02] Scan retry/rate-limit:** GET trạng thái được parse thêm `retryAllowed` và `maxProcessingSeconds`; khi được phép, FE gọi `POST .../face-scan/retry` thay vì tạo thêm force scan. Lỗi `429 FACE_SCAN_FORCE_RESCAN_RATE_LIMITED` đọc `retryAfterSeconds`, `cooldownSeconds` và header `Retry-After`, khóa nút và đếm ngược. Swagger live vẫn thiếu response schema cho POST scan, GET status và POST retry; parser status vì vậy giữ dạng phòng thủ.
- **[MỚI 2026-07-28] Gỡ tag — quyền fail-open:** response tag của `GET .../tags` **không** được Swagger document field quyền nào. FE đọc `permissions.canRemove`/`canRemove` nếu có, còn **thiếu thì vẫn cho bấm gỡ** và để BE trả 403 (`AlbumTag.canRemove` = `canRemoveFlag ?? true`). Lý do: tag do AI tự gắn buộc phải gỡ được, nếu default `false` thì BE thiếu field là user mắc kẹt với tag sai. Nếu BE chốt được contract quyền, sửa lại theo BE.
- **[MỚI 2026-08-16, BE xác nhận + verify qua `/api/docs-json` server live, wire FE Phase 1+2] Album Collection + analyze-draft:** file dump `family-care-api.json` ở root repo là bản cũ, **không** có 3 endpoint dưới — đã verify trực tiếp qua swagger live trước khi code.
  - `GET/POST /albums/collections` (`CreateAlbumCollectionDto {name (bắt buộc, max 120), description?, coverMediaId?}`) · `GET/PATCH/DELETE /albums/collections/{collectionId}` (`UpdateAlbumCollectionDto`, gửi `description`/`coverMediaId` = `null` để xóa). `DELETE` chỉ xóa mềm collection — media đã upload vẫn còn, giữ nguyên `collectionId` để audit. Swagger **chưa document response DTO** cho cả 3 method này (chỉ có request DTO) — FE parse phòng thủ (`id`, `name`, `description`, `coverMediaId`, `createdAt`, `mediaCount`). Wire: `AlbumProvider.fetchCollections/createCollection/updateCollection/deleteCollection`.
  - **[VERIFY LIVE 2026-08-16 — `mediaCount` không đáng tin]** `GET /albums/collections` trả `mediaCount = 0` cho collection đã thật sự có ảnh (upload xong, lọc `GET .../media?collectionId=` vẫn ra đúng ảnh) — field không được BE tính lại theo thời gian thực, hoặc field này chưa implement thật. FE **không hiển thị** số này ở card album nữa (chỉ hiện nhãn chung "Album") để tránh báo sai số cho người dùng. Cần hỏi BE có định tính live không trước khi hiển thị lại.
  - `POST /albums/media` và `GET /albums/media` nhận thêm `collectionId` (optional, uuid) — POST gắn media vào album khi upload, GET lọc theo album. Không truyền `collectionId` ở GET thì trả tất cả (kể cả media cũ `collectionId = null`) — đúng hành vi "Tất cả ảnh".
  - `POST /albums/media/analyze-draft` — multipart `{file (bắt buộc), collectionId?, topic? (max 120), declaredContentIntent? (PEOPLE | SCENE_OR_OBJECT)}`. Theo mô tả BE: **không lưu DB, không upload R2, không gọi face-scan** — chỉ cảnh báo mềm. Response chưa có DTO trong Swagger; field xác nhận qua BE (không phải suy đoán): `recommendation` (`ALLOW | WARN`), `analysisStatus` (`COMPLETED | SKIPPED | UNAVAILABLE`), `warnings[]`, `detectedLabels[]`, `summary`. `SKIPPED`/`UNAVAILABLE` **không chặn** upload — FE hỏi xác nhận rồi vẫn cho tải lên bình thường. Wire: `AlbumProvider.analyzeDraft`, gọi trước `uploadMedia` trong `_analyzeAndUpload` (`album_screen.dart`).
  - Không đụng face recognition (`AlbumFaceProvider`/`AlbumFaceSection`/face-scan/face-suggestions) — 2 flow độc lập hoàn toàn, giữ nguyên như trước.
  - **[BE FIX 2026-08-17 (đợt 3) — parser fallback plain-text của `analyze-draft`, FE KHÔNG phải đổi code]** BE vá nốt 3 điểm FE báo sau đợt test 7 lượt hôm 16-17/08: (1) **giảm false positive `hasPerson = true`** với ảnh vật thể/trái cây; (2) **không suy ra `detectedLabels` từ raw reasoning nữa** nên hết nhãn ảo kiểu `mountain` cho ảnh dứa/đào; (3) **lọc bỏ text placeholder** `"short reason or empty string"` khỏi `warnings` (trước đây lộ thẳng ra UI). **[VERIFY]** FE chưa retest sau khi BE deploy — phải chạy lại đúng bộ ảnh cũ (trái cây tổng hợp, dâu tây, dứa) gán vào album lệch chủ đề (`sea` / `anh LMH`) rồi mới gỡ nhãn. Đây cũng là **cơ hội đầu tiên verify được nhánh `WARN`** của `_analyzeAndUpload` (`album_screen.dart`) — nhánh này viết đúng spec nhưng **chưa từng chạy thật lần nào** vì trước bản vá `recommendation` luôn ra `ALLOW`.
  - **[XÁC MINH 2026-08-17 — BE KHÔNG có 2 thứ sau]** grep toàn bộ `family-care-api.json`: (1) **không có endpoint xóa hàng loạt** nào cho album (chỉ `bulk`/`batch` duy nhất trong repo là `sos/alerts/{alertId}/locations/batch`); (2) **không có field `isPinned`/`favorite`/`starred`** trên media, cũng không có endpoint ghim. Hệ quả FE: xóa nhiều ảnh = gọi `DELETE /albums/media/{mediaId}` **tuần tự N lần** (`AlbumProvider.softDeleteMany`, có tiến độ + báo số lỗi, không nguyên tử); ghim ảnh lưu **cục bộ theo máy** (`AlbumPinStore`, `flutter_secure_storage`, khóa `album_pinned_{userId}_{familyId}`), UI gắn nhãn "chỉ trên máy này". Đề xuất BE bổ sung: `DE_XUAT_BE_ALBUM_PIN_BULK_DELETE_2026-08-17.md` (mức Nên có, không chặn).

### Finance — Model & Jars
- `GET /api/v1/families/{familyId}/finance/model-templates` — Mẫu có sẵn: `FIVE_JARS`, `EIGHTY_TWENTY`, `CUSTOM` (constant, không lưu DB). **[wire FE 2026-07-08]** nút ℹ️ trong `FinanceModelScreen` (info sheet, không đổi luồng chọn mô hình — UI đã hardcode đúng theo mẫu này từ trước).
- `GET /api/v1/families/{familyId}/finance/models` — Mô hình tài chính (member thường chỉ thấy model active).
- `POST /api/v1/families/{familyId}/finance/models` — Tạo model + hũ mặc định. Body `CreateFinanceModelDto { modelType, name }`. 403 nếu không có quyền quản lý tài chính.
- `PATCH /api/v1/families/{familyId}/finance/models/{modelId}/activate` — Kích hoạt model, vô hiệu model cũ.
- `GET /api/v1/families/{familyId}/finance/jars` — Hũ tài chính (member thường chỉ thấy hũ của model active).
- `POST /api/v1/families/{familyId}/finance/jars` — Tạo hũ. Body `CreateFinanceJarDto`. 400 nếu tổng tỷ lệ phân bổ vượt 100%.
- `PATCH /api/v1/families/{familyId}/finance/jars/{jarId}` — Cập nhật hũ. 400 nếu tổng tỷ lệ vượt 100%.

### Finance — Categories
- `GET /api/v1/families/{familyId}/finance/categories` — Danh mục tài chính.
- `POST /api/v1/families/{familyId}/finance/categories` — Tạo danh mục. Body `CreateFinanceCategoryDto { name, categoryType, essentialType? }`.
  - `categoryType`: `INCOME | EXPENSE` · `essentialType`: `ESSENTIAL | NON_ESSENTIAL | NEUTRAL` (default `NEUTRAL`).

### Finance — Category → Jar Mapping **[MỚI 2026-07-30, wire FE]**
- `GET /api/v1/families/{familyId}/finance/category-jar-mappings?financeModelId=` — lấy mapping của ACTIVE model hoặc model chỉ định.
- `POST /api/v1/families/{familyId}/finance/category-jar-mappings` — upsert body `{financeModelId, categoryId, jarId}`.
- `DELETE /api/v1/families/{familyId}/finance/category-jar-mappings/{mappingId}` — bỏ mapping.
- UI: Mô hình tài chính → **Gán danh mục vào hũ**. Chỉ map danh mục chi đang hoạt động với hũ active thuộc đúng model.
- Khi tạo giao dịch, FE ưu tiên gửi `categoryId` và bỏ `jarId`; BE tự gán hũ theo mapping của model ACTIVE. Giao dịch cũ không có mapping giữ nguyên và nằm trong `unmapped`.
- Swagger live đã có response DTO/example cho GET/POST/DELETE mapping. Parser FE hỗ trợ đúng object lồng `category`, `jar`, `financeModel` và vẫn chịu được field phẳng của dữ liệu cũ.

### Finance — Spending Support Requests
- `GET /api/v1/families/{familyId}/finance/support-requests` — Danh sách. Query: `page, limit, status, requesterMemberId, categoryId, fromDate, toDate, mine`.
  - `status`: `PENDING | APPROVED | REJECTED | CANCELED`.
- `POST /api/v1/families/{familyId}/finance/support-requests` — Tạo yêu cầu cho bản thân. Body `CreateSpendingSupportRequestDto { amount, purpose, categoryId? }`.
- `GET /api/v1/families/{familyId}/finance/support-requests/{requestId}` — Chi tiết. **[wire FE 2026-07-08]** tap vào `_RequestCard` → `_RequestDetailSheet` (`JsonReportView`).
- `PATCH /api/v1/families/{familyId}/finance/support-requests/{requestId}/review` — Duyệt/từ chối. Body `ReviewSpendingSupportRequestDto { decision, decisionNote?, occurredAt? }` (`decision`: `APPROVE | REJECT`).
- `PATCH /api/v1/families/{familyId}/finance/support-requests/{requestId}/cancel` — Hủy yêu cầu PENDING của bản thân.

**Response shape — [CHỐT BE 2026-08-09, hết `[VERIFY]`]:** tên người gửi nằm ở **`requesterMember.user.fullName`** — đúng như `SupportRequest.fromJson` đang đoán từ 29/07, không phải sửa. Object còn có `requesterMember`, `reviewedByMember`, `category`; riêng bản chi tiết và kết quả `review` khi APPROVE có thêm **`ledgerEntry`** (giao dịch vừa được tạo).
> FE hiện bỏ qua `ledgerEntry` — có thể hiện luôn giao dịch vừa tạo thay vì chỉ báo thành công.

**Notification — [BE ship 2026-08-09]:** tạo yêu cầu → báo **Manager/Deputy**; `approve`/`reject` → báo lại **chính người gửi**. `referenceType = SUPPORT_REQUEST`, `referenceId = SpendingSupportRequest.id`.
FE đã thêm case tương ứng trong `NotificationRouter` → `/finance/support-requests` cho **mọi role** (route phẳng, không nằm trong `_managerOnlyPaths`, nên Member mở được kết quả duyệt của mình). Ghim bằng `test/support_request_notification_test.dart`.
> Trước 09/08 BE **không** phát thông báo nào cho luồng này — Manager chỉ biết có yêu cầu nếu tự mở màn hình.

### Finance — Budget Alerts
- `GET /api/v1/families/{familyId}/finance/alerts` — Danh sách cảnh báo. Query: `page, limit, status, alertType, severity, budgetPlanId, goalId, jarId, categoryId, fromDate, toDate`.
  - `status`: `NEW | ACKNOWLEDGED | RESOLVED` · `alertType`: `OVER_BUDGET | GOAL_AT_RISK | NON_ESSENTIAL_TOO_HIGH` · `severity`: `LOW | MEDIUM | HIGH`.
- `GET /api/v1/families/{familyId}/finance/alerts/{alertId}` — Chi tiết.
- `GET /api/v1/families/{familyId}/finance/alerts/{alertId}` — Chi tiết 1 cảnh báo. **[wire FE 2026-07-08]** tap vào `_AlertCard` → `_AlertDetailSheet` (`JsonReportView`).
- `POST /api/v1/families/{familyId}/finance/alerts/recompute` — Tính lại cảnh báo. Body `RecomputeBudgetAlertsDto { budgetPlanId?, goalId?, periodStart?, periodEnd?, scope? }` (`scope`: `ALL | BUDGET | GOAL | NON_ESSENTIAL`). **[wire FE 2026-07-08]** nút 🔄 trên `FinanceAlertsScreen`.
- `PATCH /api/v1/families/{familyId}/finance/alerts/{alertId}/acknowledge` — Xác nhận đã xem.
- `PATCH /api/v1/families/{familyId}/finance/alerts/{alertId}/resolve` — Đánh dấu đã giải quyết. Body `ResolveBudgetAlertDto { note? }`.

### Finance — Reports
- `GET /api/v1/families/{familyId}/finance/reports/overview` — Báo cáo tổng quan. Query: `periodStart, periodEnd, budgetPlanId, includeAlerts, includeGoals, includeBreakdown`.
- `GET /api/v1/families/{familyId}/finance/reports/budget-goal` — Báo cáo ngân sách + mục tiêu + cảnh báo. **[wire FE 2026-07-07]** `FinanceReportsScreen` tab "Ngân sách & Mục tiêu".
- `GET /api/v1/families/{familyId}/finance/reports/non-essential-spending` — Báo cáo chi tiêu không thiết yếu. **[wire FE 2026-07-07]** `FinanceReportsScreen` tab "Chi không thiết yếu".
- `GET /api/v1/families/{familyId}/finance/reports/jar-target-actual` — so sánh target % và actual % theo hũ; query `periodStart`, `periodEnd`, `financeModelId`. UI: Báo cáo tài chính → tab **Theo hũ**, dịch trạng thái `ON_TRACK | OVER_TARGET | UNDER_TARGET`.
  - Swagger live đã có `JarTargetActualApiResponseDto`: `period`, `currency`, `financeModel`, `totals`, `items[]`, `unmapped`. FE đã wire UI có cấu trúc từ DTO này, không còn tự tính từ ledger.
  - Report chỉ tính ledger `ACTIVE`, nhóm cash-out `EXPENSE | SUPPORT | ALLOWANCE | REWARD` trong kỳ. Entry có `jarId` thuộc model cũ/khác model đang báo cáo đi vào `unmapped.legacyJarAmount`, không cộng vào hũ mới.
- **[FIX FE 2026-07-28] Tên field analytics — đã đoán sai, gây hiện 0đ âm thầm:**
  - `cash-flow-summary` → `data.totals` dùng **`incomeAmount` / `expenseAmount` / `adjustmentAmount` / `netCashFlow` / `netIncludingAdjustments` / `entryCount`** (`CashFlowTotalsResponseDto`), `data.byMonth[]` dùng cùng bộ key + `month: "2026-06"`. FE trước đó đọc `income`/`totalIncome`/`inflow` → luôn 0đ, trong khi `netCashFlow` khớp nên chỉ Net có số ⇒ card "Dòng tiền vào - ra" hiện Vào 0đ / Ra 0đ / Net 50 tỷ.
  - `member-contribution-summary` → `data.members[]` có tên thành viên ở **`member.displayName`** và **`member.user.fullName`** (`MemberContributionSummaryItemResponseDto`), KHÔNG có `memberName` ở cấp ngoài; số tiền là `sharedContribution` / `goalContribution` / `ledgerContributionTotal` / `totalContribution`. FE đọc `item['memberName']` nên mọi dòng rơi về fallback "Thành viên".
  - `category-spending-summary` → `data.byCategory[]` = `{categoryId, name, essentialType, amount}`. Key `name` đã khớp; "Chưa phân loại" là **dữ liệu thật** (ledger entry không có `categoryId`), không phải lỗi parse.
  - **Bài học:** endpoint analytics có schema đầy đủ trong Swagger — phải đọc `components.schemas` thay vì đoán theo tên hợp lý, vì sai tên field không sinh lỗi HTTP nào, chỉ hiện 0.
- **[MỚI 2026-07-28, wire FE] Phân bổ theo hũ:** `POST /finance/fund-allocations {amount, periodMonth, periodYear, modelId?, note?}` đã được nối tại màn Mô hình tài chính. Dashboard và tab **Theo hũ** nay lấy `GET /reports/jar-target-actual`; file tự tính cũ `jar_allocation.dart` đã bị xóa. Form thu/chi chỉ gửi `categoryId`, không gửi `jarId`, để BE auto-map theo model ACTIVE.

### Finance — Financial Goals
- `GET /api/v1/families/{familyId}/finance/financial-goals` — Danh sách. Query: `page, limit, status, relatedJarId, includeProgress`. `status`: `ACTIVE | ACHIEVED | CANCELED | AT_RISK`.
- `POST /api/v1/families/{familyId}/finance/financial-goals` — Tạo mục tiêu. Body `CreateFinancialGoalDto { goalName, targetAmount, deadline?, monthlyContributionTarget?, relatedJarId? }`.
- `GET /api/v1/families/{familyId}/finance/financial-goals/{goalId}` — Chi tiết + tiến độ. **[wire FE 2026-07-08]** `GoalDetailScreen` (`/manager/goal-detail?goalId=`).
- `PATCH /api/v1/families/{familyId}/finance/financial-goals/{goalId}` — Cập nhật. **[wire FE 2026-07-08]** nút sửa trong `GoalDetailScreen`.
- `PATCH /api/v1/families/{familyId}/finance/financial-goals/{goalId}/cancel` — Hủy mục tiêu.
- `GET /api/v1/families/{familyId}/finance/financial-goals/{goalId}/progress` — Tiến độ tính toán. **[wire FE 2026-07-08]** `GoalDetailScreen` mục "Tiến độ chi tiết" (`JsonReportView`, schema không document).

### Finance — Goal Contribution Plans — **[wire FE 2026-07-07]**
- `GET .../financial-goals/{goalId}/contribution-suggestions` — Gợi ý đóng góp/tháng theo từng thành viên. Query `month`, `year` (bắt buộc).
  - **[BE ĐỔI LOGIC 2026-08-18 — đã wire FE]** Khoản **đã góp quỹ chung KHÔNG còn bị lấy làm "số phải góp tiếp cho mục tiêu"**, nó chỉ **trừ bớt khả năng còn lại**. Công thức BE: `availableAmount = incomeAmount - personalExpenseAmount - sharedContributionAmount`; `suggestedContribution = contributionTargetAmount * availableAmount / totalAvailableAmount`.
  - Response có thể là **mảng cũ** hoặc **object mới** `{ suggestions[], skippedMembers[], warnings[], basis, monthlyContributionTarget, explicitMonthlyContributionTarget, recommendedMonthlyContribution, remainingAmount, totalAvailableAmount }`. FE parse được **cả hai** (`ContributionSuggestionResult.fromJson`) nên không vỡ dù BE deploy trước hay sau.
  - Mỗi phần tử `suggestions[]` thêm: `suggestedContribution` (tên mới của `suggestedAmount`), `incomeAmount`, `personalExpenseAmount`, `sharedContributionAmount`, `availableAmount`, `incomeSource`, `expenseSource`, `sharedContributionSource`, `displayName` ở gốc.
  - `skippedMembers[].reason` đã biết 4 mã: `MISSING_MONTHLY_FINANCE`, `INCOME_NOT_VISIBLE`, `EXPENSE_NOT_VISIBLE`, `NO_AVAILABLE_AMOUNT` — FE dịch sang tiếng Việt, mã lạ hiển thị nguyên văn thay vì nuốt.
  - **POST `.../contribution-plans/confirm` GIỮ NGUYÊN body cũ** `{ periodMonth, periodYear, dueDate, members[{memberId, plannedAmount}] }` — REST **không** nhận `distributionMode`. Chỉ luồng AI mới có `distributionMode` trong `pendingAction`.
  - Wire FE: `FinanceProvider.fetchContributionSuggestionResult` (bản cũ `fetchContributionSuggestions` giữ lại, trả `.suggestions`), màn `goal_contribution_screen.dart`. **[VERIFY]** chưa chạy runtime với BE thật sau khi BE deploy.
- `POST .../financial-goals/{goalId}/contribution-plans/confirm` — Xác nhận/cập nhật kế hoạch đóng góp theo tháng. Body `ConfirmGoalContributionPlanDto { periodMonth, periodYear, dueDate, members[] }`.
- `POST .../financial-goals/{goalId}/contribution-plans/{planId}/submit` — Thành viên xác nhận đã đóng góp. Body `SubmitGoalContributionPlanDto { amount, note? }`.
- `POST .../financial-goals/{goalId}/contribution-plans/{planId}/approve` — Manager/deputy duyệt khoản đóng góp (ghi vào sổ sách). Body `ReviewGoalContributionPlanDto { note? }`.
- `POST .../financial-goals/{goalId}/contribution-plans/{planId}/reject` — Manager/deputy từ chối. Body `ReviewGoalContributionPlanDto { note? }`.
- `GET .../financial-goals/{goalId}/contribution-plans` — Planned vs actual theo thành viên. Query `month`, `year` (bắt buộc).
- `GET .../financial-goals/{goalId}/contribution-shortage` — Tổng thiếu hụt đóng góp theo tháng. Query `month`, `year` (bắt buộc).
- **FE**: `GoalContributionScreen` (`/manager/goal-contribution?goalId=`), nút vào từ `financial_goal_screen.dart`.
  `[VERIFY]` response schema của GET (suggestions/plans/shortage) **không được document** — `finance_provider.dart` parse
  phòng thủ nhiều tên field khả dĩ (`GoalContributionPlan.fromJson`), field `status` (PENDING/SUBMITTED/APPROVED/REJECTED)
  là **suy luận theo luồng submit→approve/reject**, chưa xác nhận với BE thật. `memberId` giả định = `user.id`
  (không phải `familyMember.id`) — khớp cách `monthly-finances/me` scope theo user. Cần chạy thật để xác nhận.

### Finance — Goal Allocations
- `GET .../financial-goals/{goalId}/allocations` — Danh sách giao dịch đã phân bổ vào mục tiêu. **[wire FE 2026-07-08]** `GoalDetailScreen` mục "Lịch sử đóng góp".
- `POST .../financial-goals/{goalId}/allocations` — Phân bổ 1 phần giao dịch. Body `CreateGoalAllocationDto { ledgerEntryId, amount }`.
- `PATCH .../finance/goal-allocations/{allocationId}` — Cập nhật số tiền phân bổ. Body `UpdateGoalAllocationDto { amount }`. **[wire FE 2026-07-08]** nút sửa trên từng dòng lịch sử.
- `DELETE .../finance/goal-allocations/{allocationId}` — Xóa phân bổ. **[wire FE 2026-07-08]** nút xóa trên từng dòng lịch sử.

### Finance — Budget Plans & Lines
- `GET .../finance/budget-plans` — Danh sách. Query: `page, limit, status, periodType`. `status`: `DRAFT | ACTIVE | CLOSED | CANCELED` · `periodType`: `MONTHLY | QUARTERLY | YEARLY`.
- `POST .../finance/budget-plans` — Tạo (trạng thái DRAFT). Body `CreateBudgetPlanDto { planName, periodType, periodStart, periodEnd, expectedSharedIncome?, expectedSharedExpense?, lines[]? }`.
- `GET .../finance/budget-plans/{budgetPlanId}` — Chi tiết (kèm `lines`). **[wire FE 2026-07-08]** `BudgetPlanDetailScreen` (`/manager/budget-plans/detail?planId=`), tap vào thẻ plan.
- `PATCH .../finance/budget-plans/{budgetPlanId}` — Cập nhật plan DRAFT. **[wire FE 2026-07-08]** nút sửa trong `BudgetPlanDetailScreen` (chỉ hiện khi DRAFT).
- `PATCH .../finance/budget-plans/{budgetPlanId}/activate` — Kích hoạt. 409 nếu đã có plan ACTIVE cùng kỳ.
- `PATCH .../finance/budget-plans/{budgetPlanId}/close` — Đóng plan đang ACTIVE.
- `PATCH .../finance/budget-plans/{budgetPlanId}/cancel` — Hủy plan DRAFT hoặc ACTIVE.
- `GET .../finance/budget-plans/{budgetPlanId}/report` — Báo cáo planned-vs-actual. **[wire FE 2026-07-07]** `FinanceReportsScreen` tab "Ngân sách" (chọn plan qua dropdown).
- `POST .../finance/budget-plans/{budgetPlanId}/lines` — Thêm dòng vào plan DRAFT. Body `CreateBudgetLineDto`.
- `PATCH .../finance/budget-lines/{budgetLineId}` — Cập nhật dòng (plan DRAFT). **[wire FE 2026-07-08]** nút sửa trên từng dòng trong `BudgetPlanDetailScreen`.
- `DELETE .../finance/budget-lines/{budgetLineId}` — Xóa dòng (plan DRAFT). **[wire FE 2026-07-08]** nút xóa trên từng dòng.

> ✅ `budget-plans` ⇄ `budget-lines` đã tách bảng riêng — khớp hướng fix ERD Review 2 (`budget_plan` cần tách category/execution).

### Finance — Ledger & Overview
- `GET .../finance/ledger/entries` — Sổ tài chính chung. Query `month`, `year` (default tháng/năm hiện tại). **Vẫn không có filter `memberId`.**
- `POST .../finance/ledger/entries` — Tạo giao dịch nội bộ. Body `CreateLedgerEntryDto`.
- `GET .../finance/overview` — Tổng quan sổ chung + tài chính tháng của bản thân. Query `month`, `year`.

**Quan hệ giao dịch ↔ hũ — [CHỐT BE 2026-08-09]:** DB có **`LedgerEntry.jarId` trực tiếp**. Tạo entry mà gửi `categoryId` nhưng **không** gửi `jarId` thì BE tự map qua **`FinanceCategoryJarMapping`** — đúng như form thu/chi của FE đang làm (`wallet_screen.dart` cố ý không gửi `jarId`).

⚠️ **`summary.spending.byJar` vẫn `Reserved` và luôn trả `[]` — đừng dùng.** Báo cáo theo hũ thật nằm ở `GET /finance/reports/jar-target-actual` (FE đã dùng ở `finance_reports_screen.dart` và `wallet_screen.dart`). BE cho biết không ưu tiên điền `byJar` vì đã có report riêng; FE **không** chờ field này.

### Invitations — **[FLOW ĐỔI HẲN — claim → approve]**
- `POST /api/v1/families/{familyId}/invitations` — Mời member (FAMILY_MANAGER only). Body `CreateInvitationDto { email, invitedPhone?, familyRole?, relationship? }`.
  - `familyRole`: `FAMILY_MANAGER | DEPUTY_MEMBER | FAMILY_MEMBER` (default `FAMILY_MEMBER`).
- `GET /api/v1/families/{familyId}/invitations` — **[MỚI]** Danh sách lời mời của family (FAMILY_MANAGER only). Query `status`.
  - `status`: `PENDING | CLAIMED | APPROVED | REJECTED | ACCEPTED | EXPIRED | CANCELED`. Dùng `?status=CLAIMED` để xem yêu cầu chờ duyệt.
- `GET /api/v1/invitations/{token}` — Tra cứu lời mời theo token (public).
- `POST /api/v1/invitations/{token}/claim` — **[MỚI, thay cho /accept]** Gửi yêu cầu join → chờ Manager duyệt. Yêu cầu đăng nhập.
  - 400 hết hạn / không PENDING · **403 nếu email đăng nhập khác email được mời** · 409 nếu đã là member.
- `POST /api/v1/invitations/{token}/reject` — Từ chối lời mời gửi tới mình (khác endpoint Manager reject ở dưới — đây là người ĐƯỢC MỜI tự chối). **[wire FE 2026-07-08]** `InvitationProvider.declineInvitation()`, nút "Từ chối lời mời này" trong `join_family_screen.dart` (cần đăng nhập).
- `POST /api/v1/families/{familyId}/invitations/{id}/approve` — **[MỚI]** Duyệt yêu cầu join → **tạo FamilyMember** (FAMILY_MANAGER only). Body `ApproveInvitationDto { familyRole?, relationship? }`. 400 nếu không ở trạng thái CLAIMED.
- `POST /api/v1/families/{familyId}/invitations/{id}/reject` — **[MỚI]** Từ chối yêu cầu join (FAMILY_MANAGER only). 400 nếu không ở trạng thái CLAIMED.

> ⚠️ **`claim` ≠ tạo member.** Claim chỉ đưa lời mời sang trạng thái `CLAIMED`. FamilyMember chỉ được tạo khi Manager gọi `/approve`.
> ⚠️ `/invitations/{token}/accept` cũ **đã bị bỏ** — `JoinFamilyScreen` gọi endpoint này sẽ 404.
> ℹ️ `claim` **có** kiểm tra email khớp (403 nếu khác) → link mời KHÔNG dùng chung cho người khác được. Trả lời câu hỏi mở trong `BE_API_REQUESTS.md` bản cũ.

> ⚠️ **Audit toàn diện Task API 2026-07-08**: 35 endpoint đã có method trong `task_provider.dart` từ trước, nhưng
> **18/36 operation chưa từng được gọi từ UI** (dead code) — trái với memory cũ "Task system đầy đủ". Đã build UI
> gọi phần lớn (task edit, assignment cancel/detail, reward-setting edit/delete, category rename, schedule
> edit + generate-assignments, và màn `RewardManagementScreen` mới hoàn toàn cho Reward Settlements/Disputes/
> Unavailability — trước đó phía Manager **không có UI nào** để mark-paid/resolve dispute/handle báo bận dù
> Member đã tạo dispute/báo bận từ lâu). Còn thiếu: `PATCH/DELETE .../tasks/proofs/{proofId}` (cần redesign luồng
> upload nhiều ảnh trước khi có điểm tích hợp hợp lý — hiện `child_tasks_screen.dart` upload+submit trong 1 lần bấm).
>
> **4 bug sai enum/DTO phát hiện khi build UI mới** (đã sửa, verify Swagger 2026-07-08):
> 1. `RewardSettlement.status` — model cũ dùng `PENDING/AWAITING_PAYMENT/PAID/CONFIRMED`, enum thật là
>    `PENDING_SETTLEMENT/WAITING_CONFIRMATION/SETTLED/DISPUTED/CANCELED`. **Hệ quả: nút "Tôi đã nhận thưởng" ở
>    `child_tasks_screen.dart` (check `status == 'PAID'`) không bao giờ hiện ra** — bug tồn tại từ trước, không
>    phải do thay đổi hôm nay.
> 2. `markRewardPaid()` gửi `{ note }`, DTO thật `MarkRewardPaidDto { externalMethod (bắt buộc), externalNote? }`.
> 3. `resolveDispute()` gửi `{ resolutionNote }`, DTO thật `ResolveRewardDisputeDto { action: ACCEPT_DISPUTE | REJECT_DISPUTE }`.
> 4. `createAllocation()` gửi body key `items`, DTO thật dùng key `allocations`.
> 5. `TaskUnavailability.status` giả định `OPEN`, enum thật là `REPORTED`.

### Tasks — Công việc
- `GET .../tasks` — Danh sách. Query: `page, limit, status, taskCategoryId, priority, taskType`. `status`: `DRAFT | ACTIVE | COMPLETED | CANCELED` · `taskType`: `AD_HOC | RECURRING`.
- `POST .../tasks` — Tạo task **AD_HOC** (không tạo phân công/thưởng). Body `CreateTaskDto`. 400 nếu cố tạo RECURRING (dùng API lịch lặp).
- `GET .../tasks/{taskId}` — Chi tiết.
- `PATCH .../tasks/{taskId}` — Cập nhật (không chuyển sang RECURRING). **[wire FE 2026-07-08]** nút sửa trong task detail sheet.
- `PATCH .../tasks/{taskId}/cancel` — Hủy (soft, chuyển CANCELED).

### Tasks — Danh mục
- `GET .../tasks/categories` — Danh sách (mọi member active). Query `page, limit, status` (`ACTIVE | INACTIVE`).
- `POST .../tasks/categories` — Tạo (Manager/Deputy). Body `CreateTaskCategoryDto { name, description? }`.
- `PATCH .../tasks/categories/{categoryId}` — Cập nhật (soft, chuyển INACTIVE thay vì xóa). **[wire FE 2026-07-08]** giữ lâu chip danh mục trong create-task sheet → đổi tên.

### Tasks — Công việc lặp lại
- `POST .../tasks/recurring` — Tạo task RECURRING + lịch lặp. Body `CreateRecurringTaskDto { title, schedule, ... }`.
- `GET .../tasks/{taskId}/schedule` — Lấy lịch lặp. **[wire FE 2026-07-08]**
- `PATCH .../tasks/{taskId}/schedule` — Cập nhật lịch lặp (áp dụng cho lần sinh sau). **[wire FE 2026-07-08]**
- `POST .../tasks/{taskId}/schedule/generate-assignments` — Sinh phân công thủ công. Body `GenerateTaskAssignmentsDto { assignedToMemberId, fromDate, toDate, startTime?, dueTime? }`. **[wire FE 2026-07-08]** — cả 3 endpoint trong `_ScheduleSheet` (task detail → "Lịch lặp & tạo phân công", chỉ hiện cho task RECURRING).

### Tasks — Phân công
- `POST .../tasks/{taskId}/assignments` — Giao task (Manager/Deputy). Body `CreateTaskAssignmentDto { assignedToMemberId, startAt?, dueAt? }`. 409 nếu member đã được giao.
- `GET .../tasks/{taskId}/assignments` — Danh sách phân công của task. Query `page, limit, status`. `status`: `ASSIGNED | IN_PROGRESS | SUBMITTED | APPROVED | REJECTED | CANCELED`.
- `GET .../tasks/my-assignments` — Phân công của bản thân. Query `page, limit, status, priority, startFrom, startTo, dueFrom, dueTo`.
- `GET .../tasks/assignments/{assignmentId}` — Chi tiết. Provider method `getAssignmentDetail()` có sẵn, chưa có UI gọi (còn dư).
- `PATCH .../tasks/assignments/{assignmentId}/start` — Bắt đầu (ASSIGNED → IN_PROGRESS, chỉ người được giao).
- `PATCH .../tasks/assignments/{assignmentId}/cancel` — Hủy phân công (Manager/Deputy). **[wire FE 2026-07-08]** nút ✕ trên assignment card (chỉ khi PENDING/IN_PROGRESS).
- `PATCH .../tasks/assignments/{assignmentId}/reassign` — Giao lại. Body `ReassignTaskDto { assignedToMemberId, startAt?, dueAt? }`.

### Tasks — Minh chứng
- `POST .../tasks/assignments/{assignmentId}/submissions` — Nộp minh chứng (chỉ người được giao). Body `CreateTaskSubmissionDto { proofs[], submissionNote? }`.
  - Với IMAGE/VIDEO/FILE: upload qua `proofs/upload` trước, lấy `fileUrl` bỏ vào body.
- `GET .../tasks/assignments/{assignmentId}/submissions` — Danh sách minh chứng của phân công. Query `status`: `WAITING_REVIEW | APPROVED | REJECTED`.
- `GET .../tasks/submissions/{submissionId}` — Chi tiết minh chứng. **[wire FE 2026-07-08]** dùng trong `_SettlementDetailSheet` (`RewardManagementScreen`) khi settlement có `submissionId`.
- `PATCH .../tasks/submissions/{submissionId}/review` — Duyệt/từ chối (Manager/Deputy). Body `ReviewTaskSubmissionDto { decision, reviewNote? }` (`decision`: `APPROVED | REJECTED`).

> ⚠️ **`fetchLatestSubmission()` vẫn bắt buộc**: `GET .../tasks/{taskId}/assignments` không trả kèm submission. Phải gọi `GET .../assignments/{id}/submissions` riêng trước khi mở approval sheet.

### Tasks — File minh chứng
- `POST .../tasks/proofs/upload` — Upload file (multipart `file`). Query `proofType?` (`IMAGE | VIDEO | FILE`). Trả `fileUrl`.
- `PATCH .../tasks/proofs/{proofId}` — Cập nhật minh chứng (chỉ khi đang chờ review).
- `DELETE .../tasks/proofs/{proofId}` — Xóa minh chứng (chỉ khi đang chờ review).

### Tasks — Không thể làm (Unavailability)
- `POST .../tasks/assignments/{assignmentId}/unavailability` — Báo không thể làm. Body `ReportTaskUnavailabilityDto { reason }`.
- `GET .../tasks/unavailabilities` — Danh sách. Query `page, limit, status, assignmentId, reportedByMemberId`. `status`: `REPORTED | HANDLED | CANCELED`. **[wire FE 2026-07-08]** tab "Báo bận" trong `RewardManagementScreen`.
- `GET .../tasks/unavailabilities/{unavailabilityId}` — Chi tiết. Provider method có sẵn, chưa có UI gọi (còn dư).
- `PATCH .../tasks/unavailabilities/{unavailabilityId}/cancel` — Hủy báo cáo (người tạo). **[wire FE 2026-07-08]**
- `PATCH .../tasks/unavailabilities/{unavailabilityId}/handle` — Xử lý (Manager/Deputy). Body `HandleTaskUnavailabilityDto { action, newAssignedToMemberId?, startAt?, dueAt?, note? }` (`action`: `REASSIGN | CANCEL_ASSIGNMENT | MARK_HANDLED`). **[wire FE 2026-07-08]**

### Tasks — Thưởng (Reward)
- `POST .../tasks/{taskId}/reward-setting` — Tạo cấu hình thưởng. Body `CreateRewardSettingDto { rewardType, rewardAmount?, rewardDescription?, autoCreateSettlement? }` (`rewardType`: `MONEY_RECORD | POINT | OTHER`).
- `GET .../tasks/{taskId}/reward-setting` — Lấy cấu hình. **[wire FE 2026-07-08]**
- `PATCH .../tasks/{taskId}/reward-setting` — Cập nhật (chỉ áp dụng cho bài nộp duyệt sau này). **[wire FE 2026-07-08]** sheet "Đặt thưởng" tự chuyển POST→PATCH nếu task đã có reward-setting.
- `DELETE .../tasks/{taskId}/reward-setting` — Xóa (chỉ khi chưa phát sinh ghi nhận). **[wire FE 2026-07-08]** nút "Xóa phần thưởng".
- `POST .../tasks/submissions/{submissionId}/reward-settlement` — Tạo ghi nhận thưởng thủ công cho bài nộp đã duyệt. Provider method có sẵn (`createSettlement`), chưa có UI gọi — có thể do `autoCreateSettlement` trong reward-setting đã tự động tạo, cần hỏi Nghĩa xác nhận trước khi build UI tạo thủ công (tránh trùng).
- `GET .../tasks/reward-settlements` — Danh sách. Query `page, limit, status, receiverMemberId, taskId`. **[wire FE 2026-07-08]** tab "Thanh toán" trong `RewardManagementScreen` (màn mới — trước đó Manager hoàn toàn không có UI xem/xử lý settlement).
  - `status` **[ĐỔI ENUM]**: `PENDING_SETTLEMENT | WAITING_CONFIRMATION | SETTLED | DISPUTED | CANCELED` — model FE cũ dùng enum sai (`PENDING/AWAITING_PAYMENT/PAID/CONFIRMED`), đã sửa 2026-07-08 (xem cảnh báo đầu mục Tasks).
- `GET .../tasks/reward-settlements/{settlementId}` — Chi tiết. **[wire FE 2026-07-08]**
- `PATCH .../tasks/reward-settlements/{settlementId}/mark-paid` — Ghi nhận đã trả ngoài hệ thống. Body `MarkRewardPaidDto { externalMethod, externalNote? }` (`externalMethod`: `CASH | BANK_TRANSFER | THIRD_PARTY_WALLET | OTHER`). **[wire FE 2026-07-08]** — trước đó FE gửi sai body `{ note }`, đã sửa.
- `PATCH .../tasks/reward-settlements/{settlementId}/confirm-received` — Người nhận xác nhận đã nhận. Đã wire từ trước nhưng **bug điều kiện hiện nút sai** (`child_tasks_screen.dart` check `status == 'PAID'` — giá trị không tồn tại) → nút không bao giờ hiện. Đã sửa thành `WAITING_CONFIRMATION` 2026-07-08.
- `PATCH .../tasks/reward-settlements/{settlementId}/cancel` — Hủy ghi nhận (khi đang chờ trả/chờ xác nhận). Đã wire từ trước, không đổi.
- `POST .../tasks/reward-settlements/{settlementId}/allocations` — Phân bổ thưởng đã nhận vào quỹ/mục tiêu. Body `CreateRewardAllocationDto { allocations[] }` (mỗi item `{ amount, jarId?, goalId? }`). Provider method có sẵn nhưng trước đó gửi sai key `items` → đã sửa thành `allocations` 2026-07-08. Chưa có UI gọi trực tiếp (còn dư, cần UI riêng nếu Member muốn tự phân bổ thưởng vào quỹ).
- `GET .../tasks/reward-settlements/{settlementId}/allocations` — Danh sách phân bổ. **[wire FE 2026-07-08]** hiển thị trong `_SettlementDetailSheet`.
- `POST .../tasks/reward-settlements/{settlementId}/disputes` — Báo chưa nhận thưởng. Body `CreateRewardDisputeDto { reason }`. Đã wire từ trước (Member), không đổi.
- `GET .../tasks/reward-disputes` — Danh sách tranh chấp. Query `page, limit, status, rewardSettlementId, reportedByMemberId`. `status`: `OPEN | RESOLVED | REJECTED`. **[wire FE 2026-07-08]** tab "Tranh chấp" trong `RewardManagementScreen` (trước đó Member tạo được dispute nhưng Manager không có UI xem/giải quyết).
- `GET .../tasks/reward-disputes/{disputeId}` — Chi tiết. Provider method có sẵn, chưa có UI gọi (còn dư).
- `PATCH .../tasks/reward-disputes/{disputeId}/resolve` — Xử lý tranh chấp. Body `ResolveRewardDisputeDto { action }` (`action`: `ACCEPT_DISPUTE | REJECT_DISPUTE`). **[wire FE 2026-07-08]** — trước đó FE gửi sai body `{ resolutionNote }`, đã sửa; dialog đổi từ ghi chú tự do sang 2 nút Chấp nhận/Từ chối.

### AI Chatbot — **[contract BE chốt 2026-08-09, FE wire đủ 10/10]**

10 operation, FE gọi đủ cả 10 trong `ai_chatbot_provider.dart`, không gọi endpoint
AI nào ngoài Swagger.

| Endpoint | FE wire | Ghi chú |
|---|---|---|
| `POST /ai-chatbot/conversations` | ✅ `createConversation` | Tạo hội thoại mới |
| `GET /ai-chatbot/conversations` | ✅ `fetchConversations` | Danh sách hội thoại của member hiện tại |
| `DELETE /ai-chatbot/conversations/{conversationId}` | ✅ `deleteConversation` | Xóa hội thoại |
| `GET /ai-chatbot/conversations/{conversationId}/messages` | ✅ `fetchMessages` | Lịch sử tin nhắn |
| `POST /ai-chatbot/conversations/{conversationId}/messages` | ✅ `sendMessage` | Gửi prompt cho AI |
| `GET /ai-chatbot/daily-brief` | ✅ `fetchDailyBrief` | Sprint 2 |
| `POST .../messages/{messageId}/confirm-action` | ✅ `confirmAction` | Action đơn lẻ, endpoint cũ |
| `POST .../messages/{messageId}/reject-action` | ✅ `rejectAction` | Action đơn lẻ, endpoint cũ |
| `POST .../messages/{messageId}/actions/{actionIndex}/confirm` | ✅ `confirmStep` | Sprint 3, action plan nhiều bước |
| `POST .../messages/{messageId}/actions/{actionIndex}/reject` | ✅ `rejectStep` | Sprint 3, action plan nhiều bước |

**Endpoint mới so với dump 226 paths:** `daily-brief`, `actions/{actionIndex}/confirm`, `actions/{actionIndex}/reject` — cả 3 đã wire. **Chưa wire:** không có endpoint AI nào mới còn trống trong dump 229 paths.

- `POST /api/v1/families/{familyId}/ai-chatbot/conversations` — tạo hội thoại. Body `CreateAiConversationDto { title? }` (bỏ trống thì BE tự đặt theo tin đầu, max 120 ký tự).
- `GET /api/v1/families/{familyId}/ai-chatbot/conversations?page=&limit=` — chỉ trả hội thoại **của chính thành viên hiện tại**. Đã verify runtime: Thành viên nhận danh sách rỗng khi chưa có hội thoại nào, không thấy hội thoại của Trưởng nhóm.
- `GET /api/v1/families/{familyId}/ai-chatbot/conversations/{conversationId}/messages?page=&limit=` — lịch sử tin nhắn.
- `POST /api/v1/families/{familyId}/ai-chatbot/conversations/{conversationId}/messages` — gửi tin. Body `SendAiMessageDto { content }` (required, max 2000). FE để timeout 30s vì AI trả chậm.
- `POST .../messages/{messageId}/confirm-action` — xác nhận đề xuất, BE mới thực sự ghi dữ liệu.
- `POST .../messages/{messageId}/reject-action` — từ chối đề xuất.
- `DELETE /api/v1/families/{familyId}/ai-chatbot/conversations/{conversationId}` — xóa hội thoại kèm toàn bộ tin nhắn.
- `GET /api/v1/families/{familyId}/ai-chatbot/daily-brief` — tổng quan hôm nay, kèm quick actions theo `uiHints`.

**[BE FIX 2026-08-17 — phạm vi tài chính của AI, FE KHÔNG phải đổi code]**
Trước bản vá, hỏi "list danh sách thu chi thực tế của từng thành viên" bị AI
trả lời "tôi không có quyền truy cập" — **kể cả tài khoản Trưởng nhóm** (đã
tự test runtime để loại trừ FE). Nguyên nhân BE xác nhận: AI **chưa có tool**
để đọc dữ liệu tháng theo từng thành viên, không phải lỗi phân quyền.

- BE thêm AI tool **`list_member_monthly_finances`**, mở cho
  `FAMILY_MANAGER` **và `DEPUTY_MEMBER`** — khớp với `canManageFinance` của
  REST, tức Deputy dùng được.
- Quyền do BE đọc từ JWT/context; **FE vẫn chỉ gửi `{ content }`**, không gửi
  role, không phải sửa gì.
- Field bị ẩn hoặc member chưa khai báo → AI nói rõ "dữ liệu bị ẩn/chưa có",
  không trả về câu từ chối chung chung nữa.
- BE cũng sửa phần đề xuất đóng góp mục tiêu tài chính: số góp mỗi thành viên
  tính theo `actualIncome - actualPersonalExpense - actualSharedContribution`,
  thiếu số thực tế thì fallback sang số dự kiến; preview xác nhận mục tiêu
  hiển thị căn cứ tính theo từng người. BE báo 5 test suite / 76 test pass.
- **[VERIFY]** FE chưa chạy lại runtime sau bản vá này — cần test lại đúng câu
  trên bằng **cả Trưởng nhóm lẫn Phó nhóm** rồi mới gỡ nhãn.

**Hai điểm BE trả về cho FE tự xử (BE xác nhận không nằm trong scope của họ):**
- **Markdown `###` lộ ra UI:** BE trả markdown, FE chưa render/lược. Logic BE
  không sai — FE tự render hoặc lược ký hiệu.
- **Tên hũ `Savings`/`Spending`:** là **dữ liệu** (tên hũ mặc định BE tạo),
  không phải chuỗi trong FE. Muốn tiếng Việt phải đổi tên hũ trong dữ liệu,
  hoặc BE map display name trước khi đưa vào response AI.

**Sprint 3 (2026-08-09, backward-compatible — BE xác nhận endpoint cũ ở trên
giữ nguyên, FE không bắt buộc đổi flow ngay):** một `aiMessage` giờ có thể có
NHIỀU đề xuất cùng lúc trong `pendingActions[]` (kế hoạch nhiều bước),
`pendingAction` (số ít) **vẫn còn, là alias của `pendingActions[0]`**. Nếu
`aiMessage.uiHints.displayStyle === "ACTION_PLAN_CARD"` thì render card kế
hoạch nhiều bước, mỗi phần tử `pendingActions[n]` có thêm `actionIndex` (vị
trí bước) để xác nhận/từ chối RIÊNG từng bước, khác hẳn 2 endpoint cũ vốn
thao tác theo `messageId` (chỉ áp dụng khi action đơn lẻ, không phải plan).
**Đã verify runtime 2026-08-09** (câu "Giúp tôi chuẩn bị cho chuyến du lịch:
tạo lịch đi chơi cuối tuần này và ghi khoản chi 500.000đ tiền đặt cọc" ra
đúng 1 message với `pendingActions[]` 2 phần tử, xác nhận/từ chối độc lập
từng bước đúng, plan-level "Kế hoạch đã hủy" đúng khi mọi bước đều bị từ
chối) — cả 2 endpoint dưới đây đều hoạt động đúng, không còn `[VERIFY]`:

- `POST .../messages/{messageId}/actions/{actionIndex}/confirm` — xác nhận
  một bước.
- `POST .../messages/{messageId}/actions/{actionIndex}/reject` — từ chối một
  bước.

FE đã wire ở `AiChatbotProvider.confirmStep`/`rejectStep`,
`_ActionPlanCard`/`_PendingActionCard(stepIndex: ...)` trong
`ai_assistant_screen.dart`. `AiPendingAction.actionIndex` mặc định `0` nếu
JSON không có field này (tương thích action đơn lẻ trước Sprint 3, luôn được
coi là "bước 0" duy nhất).

**`pendingAction` — chỉ hiện thẻ xác nhận khi response CÓ khối này.**

```jsonc
{
  "pendingAction": {
    "messageId": "ai-message-id",
    "actionType": "CREATE_CALENDAR_EVENT",
    "preview": { "title": "...", "startTime": "...", "location": "..." },
    "expiresAt": "2026-08-07T12:15:00.000Z"
  }
}
```

- `actionType` chính thức, **9 giá trị** (Swagger 2026-08-09): `CREATE_LEDGER_ENTRY`, `CREATE_BUDGET_PLAN`, `CREATE_BUDGET_LINE`, `CREATE_FINANCIAL_GOAL`, `CREATE_GOAL_ALLOCATION`, `CREATE_GOAL_CONTRIBUTION_PLAN`, `ALLOCATE_FUND_BY_MODEL`, `CREATE_TASK`, `CREATE_CALENDAR_EVENT`. Sau confirm các action tài chính phải refresh Wallet/Budget/finance overview — FE gọi `FinanceProvider.fetchAll()`.
- `status` chính thức, **đúng 4 giá trị**: `PENDING` → `CONFIRMED` (confirm thành công) / `REJECTED` (người dùng từ chối) / `EXPIRED` (quá hạn). **Không có `CANCELED` hay `FAILED`.**
- Sau confirm thành công, status lưu trên tin nhắn AI gốc là `CONFIRMED` và **`result.id` là id bản ghi vừa tạo** (FE hiện chưa dùng field này — có thể dùng sau để deep-link tới bản ghi).
  - **[CHỐT BE 2026-08-09]** `result` chỉ có đúng `{ id }` là **cố ý**, không phải tạm thời. FE gọi lại API lấy chi tiết là cách đúng.
  - **`categoryId` của giao dịch do AI tạo:** chỉ có nếu payload AI gửi kèm. AI tự tra `list_finance_categories`; khớp rõ thì đưa `categoryId`, không khớp thì **để trống**. BE **không** tự suy category lúc confirm.
  - ⚠️ Hệ quả: giao dịch AI tạo có thể rơi vào "Chưa phân loại" — FE nên gợi ý chọn danh mục ngay sau khi confirm thay vì để người dùng tự phát hiện. **Chưa làm.**
- **[Sửa 2026-08-09]** `uiHints.displayStyle` của tin nhắn sau khi resolve (confirm/reject) từng có lúc trả sai `INSIGHT_CARD` kèm `content` vẫn y hệt lúc chưa xử lý ("xin xác nhận"), làm FE mất banner kết quả — BE xác nhận đã sửa tận gốc: `REJECTED`/`CONFIRMED`/`EXPIRED` giờ luôn trả đúng `RESULT_CARD`, `content` cập nhật đúng theo trạng thái thật. FE đã bỏ lớp vá tạm (ép cứng `actionCard`), tin thẳng `uiHints.displayStyle`; `_ResultCard` đổi màu/icon theo outcome (không còn mặc định xanh "thành công" cho mọi trường hợp).
- `expiresAt` là **ISO UTC thật** sinh bằng `Date.toISOString()`, có đuôi `Z`, interceptor **không** convert timezone. FE tính countdown theo UTC bình thường.
- **[Cập nhật BE 2026-08-10]** Resolver ngày tương đối giờ đọc cả context
  message user trước đó. Luồng AI hỏi thêm giờ/địa điểm cho “cuối tuần này”
  phải normalize về 15–16/08 (không còn lệch 13/08); cần regression runtime.
- **[Cập nhật BE 2026-08-10]** `ALLOCATE_FUND_BY_MODEL` có guardrail quyền
  riêng và fallback recover `pendingAction`: Manager/Deputy yêu cầu chia quỹ
  tháng tương lai không còn bị trả text `PERMISSION_NOTICE` sai; cần regression
  runtime để xác nhận luôn có thẻ xác nhận.
- **[Cập nhật BE 2026-08-10 — content PENDING chuẩn hóa]** Khi response có
  `pendingAction`/`pendingActions[]` với `status = PENDING`, BE không dùng lại
  text do model sinh tự do mà trả content chuẩn theo `actionType`. Riêng
  `CREATE_CALENDAR_EVENT` trả: “Mình đã tạo đề xuất lịch. Vui lòng kiểm tra
  thông tin và xác nhận trên ứng dụng để hoàn tất nhé.” FE giữ nguyên content
  server trả về và render thẻ dựa trên cấu trúc action, không suy đoán theo chữ.
- **[BE fix verified 2026-08-12 — calendar participants]** Với
  `CREATE_CALENDAR_EVENT`, prompt “cho cả nhà”/“cả gia đình”/“mọi người” được BE map
  sang toàn bộ member `ACTIVE`; nếu không nêu participant thì thêm người tạo. ID do AI
  trả phải được xác thực thuộc member active trước khi tạo pending action. Runtime đã
  xác nhận proposal mới tạo lịch cho cả nhà confirm thành công; FE vẫn chỉ gửi
  `messageId` vào endpoint confirm và không tự tạo participant payload.
- **Cập nhật 2026-08-07:** `entryDate` của Ledger **cũng là UTC thật**, không còn phải wall-clock local gắn `Z` như ghi nhận trước đây. Verify runtime: tạo khoản chi lúc 20:19 giờ VN (13:19 UTC), sổ thu chi từng hiện `13:18` — lộ ra `WalletProvider.displayEntryDate` tự cắt `Z` rồi đọc số UTC như giờ local, lỗi FE đã sửa (không phải BE). **Support request chưa verify lại** — nếu đụng tới thì phải test runtime riêng, không suy diễn theo ledger.
- **[Sửa 2026-08-09]** `CREATE_LEDGER_ENTRY` từng lỗi chập chờn không sinh `pendingAction` (AI tự báo lỗi định dạng ngày). Nguyên nhân: `entryDate` do AI sinh ra không ổn định format. BE đã normalize trước khi validate: `YYYY-MM-DD` → `YYYY-MM-DDT00:00:00+07:00`; datetime thiếu timezone → tự thêm `+07:00`; text/ngày không parse được → fallback ngày hiện tại theo giờ VN. Cần test lại luồng "Ghi khoản chi ... hôm nay/tuần này" để xác nhận đã hết chập chờn.
- **[Sửa 2026-08-09]** Thông báo từ chối quyền (`PERMISSION_NOTICE`, "Bạn không có quyền...") từng mất dấu tiếng Việt không nhất quán — BE xác nhận đã sửa, giờ có dấu đầy đủ.
- **[Sửa 2026-08-09]** AI context cho `list_family_members` từng chỉ có ID/"chưa có tên hiển thị" — BE đã bổ sung fallback: `displayName` → `user.fullName` → `user.email`.
- **[Làm rõ 2026-08-09]** Nút "Sửa" (`editActionLabel`): BE xác nhận KHÔNG có endpoint edit pending action. Luồng chính thức: FE dùng `pendingAction.preview` để mở form tạo dữ liệu tương ứng, prefill sẵn, cho người dùng chỉnh trước khi lưu. FE hiện chưa có form prefill riêng cho từng actionType, nên áp dụng fallback BE xác nhận là hợp lệ: từ chối đề xuất hiện tại rồi để người dùng gõ lại.
- Field `preview` của `CREATE_TASK` dùng tên **`task`** (không phải `title`) — quan sát runtime 2026-08-07.
- Lỗi: `403` không có quyền tạo · `409` đề xuất đã xử lý rồi · `410` hết hạn, phải chat lại để AI tạo đề xuất mới.
- Sau confirm thành công phải reload đúng module: task → danh sách nhiệm vụ · ledger → finance ledger/overview · calendar → sự kiện lịch (**theo tháng của `startTime`**, không phải tháng hiện tại) · budget plan → `FinanceProvider.fetchAll()`.
- FE **không** được tự tạo dữ liệu từ `preview`; `preview` chỉ để người dùng đối chiếu.

**Phân quyền (BE chốt 2026-08-07):** thao tác ghi tài chính `CREATE_LEDGER_ENTRY`
chỉ mở cho `FAMILY_MANAGER` và `DEPUTY_MEMBER`. Thành viên thường **không nhận
`pendingAction`**; BE trả câu trả lời thường giải thích nên nhờ Trưởng/Phó nhóm.
FE đã ẩn sẵn các gợi ý tạo dữ liệu với Thành viên (`aiPromptGroupsFor`).

**Feature flag:** `ai.assistant` là key gate màn Trợ lý AI. Ba key
`ai.financeSummary`, `ai.taskSummary`, `ai.savingSuggestions` hiện **chỉ là cờ
điều khiển hành vi bên trong chatbot/tool access, KHÔNG phải endpoint riêng** và
BE cũng chưa guard chúng — FE không gate theo ba key này, chỉ đọc để hiển thị
quyền lợi ở màn Gói đăng ký.

**✅ Swagger đã có response DTO đầy đủ (bản dump 2026-08-09).** `POST .../messages`
nay khai cả `200`. Các schema chính thức:

- `AiActionType` (enum) — đúng 9 giá trị, khớp `AiPendingAction.confirmedActionTypes`.
- `AiActionStatus` (enum) — đúng 4 giá trị, khớp `AiPendingAction.confirmedStatuses`.
- `AiPendingActionResponseDto` — `messageId`, `actionIndex`, `actionType`, `status`, `preview`, `expiresAt`, `uiHints` (bắt buộc) + `result` (tuỳ chọn, `AiActionResultResponseDto { id }`).
- `AiMessageResponseDto` — `id`, `senderType`, `content`, `relatedModule` (nullable), `createdAt`, `pendingAction` (nullable), `pendingActions[]`, `uiHints`. **Mỗi tin nhắn trong lịch sử có thể tự mang `pendingAction`/`pendingActions`**, không chỉ response lúc gửi.
- `AiSendMessageDataResponseDto` — `{ userMessage, aiMessage, pendingAction, pendingActions }`, bắt buộc theo Swagger, `pendingAction` nullable.
- `AiConfirmActionDataResponseDto` — `{ actionIndex, actionType, result }` · `AiRejectActionDataResponseDto` — `{ actionIndex, actionType }`. FE bỏ qua body này và refetch messages.
- Hai endpoint list dùng `{ items, meta }` với `PaginationMetaResponseDto { page, limit, total, totalPages }` — khớp parser phân trang của FE.

**⚠️ Bẫy tên field:** `AiConversationLastMessageResponseDto` dùng
**`messageContent`**, KHÔNG phải `content` như `AiMessageResponseDto`. FE từng
đọc nhầm `content` khiến dòng xem trước dưới mỗi hội thoại **trống trơn** — lỗi
im lặng, không exception. Đã sửa, khoá bằng `test/ai_conversation_mapping_test.dart`.

Test khoá contract: `test/ai_pending_action_contract_test.dart`,
`test/ai_send_response_test.dart`, `test/ai_conversation_mapping_test.dart`.

### Subscription Plans (public/subscriber)
- `GET /api/v1/subscription-plans` — Danh sách gói active (cho subscriber).

### Admin (SYSTEM_ADMIN only — thuộc scope Duy/Admin Web, FE Mobile không dùng)
- Subscription Plans: `POST/GET /api/v1/admin/subscription-plans`, `GET/PATCH/DELETE /api/v1/admin/subscription-plans/{id}`
- Users: `GET /api/v1/admin/users`, `GET/PATCH/DELETE /api/v1/admin/users/{id}`
- Families: `GET /api/v1/admin/families`, `GET/PATCH/DELETE /api/v1/admin/families/{id}`
- Invitations: `GET /api/v1/admin/invitations`, `GET/PATCH/DELETE /api/v1/admin/invitations/{id}`
- Family Members: `GET /api/v1/admin/family-members`, `GET/PATCH/DELETE /api/v1/admin/family-members/{id}`

---

## Request Schemas (chính, FE Mobile hay dùng)

### RegisterDto
- `email`: string *(required)* · `password`: string *(required, ≥8, có hoa/thường/số/ký tự đặc biệt)* · `fullName`: string · `phone`: string · `avatarUrl`: string

### LoginDto / RefreshTokenDto / LogoutDto
- Login: `email` *(required)*, `password` *(required)*
- Refresh: `refreshToken` *(required)*
- Logout: `refreshToken` *(optional — có thì revoke device, không thì revoke tất cả)*

### VerifyEmailDto — **[MỚI]**
- `code`: string *(required)* — OTP 6 số

### CreateFamilyDto
- `name`: string *(required)* · `description`: string · `avatarUrl`: string · `relationship`: `FATHER | MOTHER | SPOUSE | CHILD | SISTER | BROTHER | GRANDPARENT | OTHER`

### CreateInvitationDto
- `email`: string *(required)* · `invitedPhone`: string · `familyRole`: `FAMILY_MANAGER | DEPUTY_MEMBER | FAMILY_MEMBER` (default `FAMILY_MEMBER`) · `relationship`: enum (default `OTHER`)

### ApproveInvitationDto — **[MỚI]**
- `familyRole`: `FAMILY_MANAGER | DEPUTY_MEMBER | FAMILY_MEMBER` · `relationship`: enum

### CreateCheckoutDto — **[MỚI]**
- `planCode`: string *(required)* — gói trả phí (`PLUS | PREMIUM | ...`, không phải FREE)

### CreateMemberMonthlyFinanceDto / UpdateMemberMonthlyFinanceDto
- `periodMonth`: number *(required, 1–12)* · `periodYear`: number *(required)* · `expectedIncome`, `actualIncome`, `expectedPersonalExpense`, `actualPersonalExpense`, `expectedSharedContribution`, `actualSharedContribution` (nullable) · `incomeVisibility`, `expenseVisibility`: `PRIVATE | FAMILY` · `note` (nullable)

### CreateFinanceModelDto
- `modelType`: `FIVE_JARS | EIGHTY_TWENTY | CUSTOM` *(required)* · `name`: string *(required)*

### CreateFinanceJarDto
- `financeModelId`: uuid *(required)* · `name` *(required)* · `jarCode` *(required)* · `allocationPercentage`: number *(required, 0–100)* · `description` · `isActive` (default true)

### [HOÀN THÀNH FE 2026-08-02] Mapping danh mục → hũ + report jar target/actual
Swagger live đã có contract và response example cho mapping/report; source mobile hiện đã wire đủ các endpoint dưới đây.

**BE bổ sung flow mapping `category → jar` theo từng finance model:**
- `GET /families/{familyId}/finance/category-jar-mappings`
- `POST /families/{familyId}/finance/category-jar-mappings`
- `DELETE /families/{familyId}/finance/category-jar-mappings/{mappingId}`
- Report mới: `GET /families/{familyId}/finance/reports/jar-target-actual` — target % vs actual % từng hũ, `status ∈ { ON_TRACK, OVER_TARGET, UNDER_TARGET }`.

**Quy tắc nghiệp vụ BE nêu:**
1. Manager chọn model 5 hũ / 80-20 → cần cấu hình **category nào thuộc hũ nào**.
2. Khi tạo giao dịch, FE **chỉ cần gửi `categoryId`**. **Không gửi `jarId`** thì BE tự gán theo mapping của model **ACTIVE**.
3. Giao dịch cũ chưa có mapping nằm trong nhóm **`unmapped`**; BE **không sửa lịch sử**.
4. BE khuyến nghị FE ưu tiên chọn **category** khi nhập thu/chi, để BE auto-map hũ.

**Trạng thái code hiện tại:**
- Form ghi thu/chi đã bỏ picker hũ và không gửi `jarId`; category là nguồn để BE tự map.
- Dashboard và tab **Theo hũ** gọi `GET /finance/reports/jar-target-actual`; phần tự cộng local đã được xóa.
- Mapping được tải/lưu/xóa theo `financeModelId`, nên đổi 5 hũ ↔ 80/20 không làm mất mapping của model trước.

### [CHỐT BE 2026-08-07] Wearable pairing + activation — mã `FCW` do BE cấp
- Wear OS gọi `POST /wearable-activations` để lấy `sessionId` bí mật và `code` công khai, ví dụ `FCW-8SRERK`.
- Mobile FE cho user nhập `code` này rồi gọi endpoint pair hiện có; với endpoint pair, `code` chính là `deviceIdentifier`:
  ```http
  POST /api/v1/families/{familyId}/wearables
  ```
  ```json
  {
    "deviceName": "Wear OS",
    "deviceType": "SMARTWATCH",
    "deviceIdentifier": "FCW-8SRERK"
  }
  ```
- `GET /api/v1/wearables/me` **chỉ** dùng để check user hiện có wearable đang `PAIRED` chưa. Nếu trả `null`, mobile phải cho user nhập mã đang hiện trên đồng hồ.
- Sau khi mobile pair xong, Wear OS poll `GET /wearable-activations/{sessionId}` tới khi `status=PAIRED`, rồi gọi `POST /wearable-activations/{sessionId}/claim` để nhận `accessToken`, `refreshToken`, `user`.
- FE coi `status=EXPIRED` từ BE là nguồn sự thật duy nhất để hết hạn mã; không tự so `expiresAt` với giờ máy vì emulator Wear OS có thể lệch thời gian. **BE xác nhận 09/08:** không có cron dọn phiên, BE tính hết hạn ngay lúc `create` / `getStatus` / `claim` — nên cách FE poll `getStatus` rồi tin `status` là đúng.
- **Vòng đời (BE xác nhận 09/08):** activation session sống **10 phút**. Token cấp cho đồng hồ dùng **chung cơ chế token thường**, không có scope riêng: access **15 phút**, refresh **7 ngày**.
  - Hệ quả: đồng hồ để yên quá 7 ngày là phải ghép nối lại. FE nên nói thẳng câu này thay vì hiện lỗi xác thực chung chung.
- **Mã lỗi của `POST /wearable-activations/{sessionId}/claim` (BE xác nhận 09/08 — Swagger chỉ khai 200):**

  | Tình huống | HTTP | `code` / `errorCode` |
  |---|---|---|
  | Phiên đã hết hạn | `410` | `ACTIVATION_EXPIRED` |
  | Đã claim rồi (gọi lần 2) | `409` | `ACTIVATION_ALREADY_CLAIMED` |
  | Điện thoại chưa nhập mã (còn `PENDING`) | `400` | `ACTIVATION_NOT_PAIRED` |
  | `sessionId` không tồn tại | `404` | `ACTIVATION_NOT_FOUND` |

  Response lỗi có **cả `code` lẫn `errorCode`**. Bắt theo `code`, **không** bắt theo `message` — message là tiếng Việt và sẽ đổi.
- Enum đã chốt: `deviceType` `SMARTWATCH | GPS_TRACKER | BLE_DEVICE | SIMULATED_DEVICE`; `pairingStatus` `PAIRED | UNPAIRED | LOST`. `PairWearableDto.deviceIdentifier` unique trong 1 family; `ownerMemberId` chỉ Manager/Deputy. Response `SosWearableDeviceResponseDto`.
- Nếu `deviceIdentifier` đã được pair bởi user khác trong family, BE trả `409 DEVICE_IDENTIFIER_TAKEN`.
- Nếu tài khoản đã có wearable `PAIRED`, BE trả `409 WEARABLE_ALREADY_PAIRED`.
- Unpair: `PATCH /families/{familyId}/wearables/{deviceId}` body `{ "pairingStatus": "UNPAIRED" }`, sau đó FE phải verify lại bằng `GET /wearables/me`.
- **FE đã chỉnh (2026-08-07):** app đồng hồ không tự sinh mã nữa; lấy mã từ BE activation, mobile mở dialog nhập mã và gửi `deviceType: SMARTWATCH`. Mobile chỉ cảnh báo mềm nếu mã không giống dạng `FCW-XXXXXX`; không khóa cứng regex vì BE mới cam kết non-empty + max 100. Không còn tự ghép mobile bằng mã `familycare-*`/`SIMULATED_DEVICE`.

### [BUG FE 2026-08-06] Ngắt kết nối wearable báo thành công khống → ghép lại 409
**Hành vi BE đã được xác nhận là đúng, đây là lỗi FE.** Quy tắc: một tài khoản chỉ được có một wearable **đang PAIRED**. Bản ghi `UNPAIRED` **không** chiếm chỗ — ghép lại cùng `deviceIdentifier` cũ thì BE pair lại chính record đó; identifier mới thì tạo record mới miễn là user không còn wearable PAIRED. Vì vậy **409 nghĩa là thực sự vẫn còn record PAIRED**.

Hai lỗi trong `WearableProvider.updateDevice()` khiến UI nói khác server:
1. **Cập nhật lạc quan trước khi gửi request** — ghi `_currentDevice` rồi `notifyListeners()` **trước** khi gọi PATCH, nên màn hình đổi sang "Chưa kết nối" ngay lập tức.
2. **Bỏ qua response khi gỡ** — `_currentDevice = pairingStatus == 'UNPAIRED' ? null : _deviceFrom(data)` gán thẳng `null` theo trạng thái *được yêu cầu*, không đọc dữ liệu BE trả về. PATCH không áp dụng được thì FE vẫn báo đã gỡ.

**Đã sửa** theo đúng khuyến nghị của BE — chỉ báo success sau khi `GET /wearables/me` xác nhận: khi `pairingStatus == 'UNPAIRED'`, gọi lại `fetchCurrentDevice()` và **ném lỗi** nếu server vẫn còn thiết bị `PAIRED`. Bỏ cập nhật lạc quan cho riêng thao tác gỡ (giữ cho đổi tên / bật-tắt GPS-SOS).

Sửa phụ đi kèm:
- Không còn đè message thật của BE khi 409 — trước đây **mọi** 409 bị thay bằng một câu cứng của FE, chính điều này che mất chẩn đoán.
- Thêm card **"Thiết bị đeo của gia đình"** (`GET /families/{familyId}/wearables`, + `DELETE` khi cần dọn) để đối chiếu trạng thái thật; hai API này đã wire ở provider từ trước nhưng **không màn nào gọi**.
- `deviceIdentifier` sinh riêng từng máy và lưu cố định, thay hằng số `wearos-emulator-001` dùng chung — `PairWearableDto` mô tả identifier "unique within a family". Mã cố định theo bản cài nên vẫn thoả "ghép lại cùng identifier thì pair lại record cũ".

Chi tiết: `DE_XUAT_BE_WEARABLE_UNPAIR_2026-08-06.md`. **Không cần BE thay đổi gì.**

### [SPEC 2026-08-04 + CHỐT BE 2026-08-07] Wear OS Flow — SOS tự động PHẢI đi qua wearable event
Nguồn: Discord *Những chiến binh làm đồ án* → `#chuc-nang-moi` → thread **"Flow của Wearable Device SOS mới"**, tin của Nhật ngày 04/08/2026.

> **Wear OS không gọi trực tiếp `/sos/alerts` cho 2 case auto-detection.** Wear OS gọi `POST /families/{familyId}/wearables/{deviceId}/events`. BE tự quyết định tạo SOS, **chống duplicate** nếu user đang có SOS active.
> - `HEART_RATE_ABNORMAL` → auto tạo SOS.
> - `FALL_DETECTED` → **chỉ** auto tạo SOS nếu `autoCreateAlertFromFall = true`.

Đây là điểm dễ làm sai nhất: gọi thẳng `/sos/alerts` vẫn "chạy được" nên không ai phát hiện, nhưng **mất chống trùng của BE** và **bỏ qua luôn cài đặt `autoCreateAlertFromFall`**.

**Luồng màn hình theo spec:**
1. Màn chính đồng hồ: trạng thái **"An toàn"**, nút chính **SOS**, kèm nút giả lập (té ngã / nhịp tim cao / nhịp tim thấp).
2. Khi phát hiện → màn cảnh báo: tiêu đề + số đo (vd `142 bpm`) + câu hỏi, **tự gửi SOS sau 20 giây**, hai nút `[Con ổn]` / `[Gửi SOS]` (nhịp tim dùng nhãn `[Đã ổn]`).
3. `Con ổn` → đóng cảnh báo, **không gọi API tạo SOS**.
4. `Gửi SOS` hoặc hết đếm ngược → gọi wearable event.
5. Sau response → màn **"Đã gửi SOS / Đang thông báo cho người thân"** + `[Hủy báo động]`.
6. Mobile người thân: **không cần flow mới**, chỉ hiển thị theo `alert.message`.

**`rawValue` đã chốt:**
- `FALL_DETECTED` — `{ gForce: 3.2, stillSeconds: 8, source: "wear_os_emulator" }`, `severity: HIGH`
- `HEART_RATE_ABNORMAL` (cao) — `{ heartRate: 142, thresholdHigh: 130, durationSeconds: 30, source: "wear_os_emulator" }`
- `HEART_RATE_ABNORMAL` (thấp) — `{ heartRate: 38, thresholdLow: 50, durationSeconds: 30, source: "wear_os_emulator" }`; BE đã xác nhận `thresholdLow` hợp lệ.

**Response `POST .../wearables/{deviceId}/events` đã có DTO/schema:**

```json
{
  "event": {
    "id": "sensor-event-id",
    "deviceId": "wearable-device-id",
    "eventType": "HEART_RATE_ABNORMAL",
    "rawValue": {
      "heartRate": 38,
      "thresholdLow": 50,
      "durationSeconds": 30
    },
    "severity": null,
    "detectedAt": "2026-08-07T12:00:00.000Z",
    "createdSosAlertId": null,
    "createdAt": "2026-08-07T12:00:00.000Z"
  },
  "alertId": "sos-alert-id-or-null",
  "alertCreated": true
}
```

- Đồng hồ **bắt buộc đã paired** trước khi gửi event; unpaired trả `WEARABLE_NOT_PAIRED`.
- Nếu owner đã có SOS `ACTIVE`, BE **không tạo thêm alert**: `alertCreated=false`, `alertId` là SOS active hiện có.
- `alert.message` cho SOS do wearable tạo là **BE sinh**; mobile chỉ hiển thị theo message này.

**Rule auto-create SOS đã chốt:**

| Event | Hành vi BE |
|---|---|
| `SOS_BUTTON_PRESSED` | Auto tạo SOS |
| `HEART_RATE_ABNORMAL` | Auto tạo SOS |
| `FALL_DETECTED` | Auto tạo SOS chỉ khi family setting `autoCreateAlertFromFall=true` |
| `HARD_IMPACT` | Chỉ ghi event |
| `ABNORMAL_MOVEMENT` | Chỉ ghi event |

**Error code wearable đã chốt:** response lỗi có cả `code` và `errorCode` trong standard error envelope: `WEARABLE_ALREADY_PAIRED`, `DEVICE_IDENTIFIER_TAKEN`, `WEARABLE_NOT_PAIRED`, `INVALID_SENSOR_EVENT_TYPE`, `INVALID_SENSOR_EVENT_PAYLOAD`.

#### [BUG FE 2026-08-07] SOS từ cảm biến không có vị trí → người nhận không thấy bản đồ

`CreateSensorEventDto` **không có trường vị trí nào**, và BE mới là bên tạo cảnh báo, nên SOS sinh từ sự kiện cảm biến có `initialLatitude`/`initialLongitude` = null và `locationPoints` rỗng. Bên người nhận, `SOSScreen._location()` trả null nên **toàn bộ khối vị trí (gồm bản đồ) không được dựng** — khác hẳn cảnh báo phát từ điện thoại. Đây là hành vi đúng của BE, thiếu sót nằm ở FE.

Đường đúng đã có sẵn trong Swagger: `PushSosLocationDto.sourceType` có giá trị **`WEARABLE_GPS`** và trường `deviceId`; endpoint `POST /sos/alerts/{alertId}/locations` giới hạn "chỉ người kích hoạt" — đồng hồ đăng nhập cùng tài khoản người đeo nên hợp lệ. **Không cần BE thay đổi gì.**

FE sửa: sau khi có `alertId` (kể cả trường hợp trùng SOS đang chạy, lúc đó `alertId` là alert active), đồng hồ đẩy một điểm vị trí với `sourceType: 'WEARABLE_GPS'` + `deviceId`. Bên người nhận phải đọc đúng mảng **`locationPoints`** của `SosAlertResponseDto`; các alias cũ `locations`/`sosLocations` chỉ giữ làm fallback.

- Nguồn vị trí: `resolveWearableSosPosition()` — **chỉ dùng GPS của chính đồng hồ**, không lùi về vị trí điện thoại cùng tài khoản. Vị trí điện thoại có thể ở nơi khác người đeo nên không được dùng làm dữ liệu khẩn cấp.
- SOS thủ công trên đồng hồ tạo cảnh báo ngay, không gửi `initialLatitude/Longitude` từ mobile; sau khi có `alertId` mới hỏi GPS đồng hồ và **đẩy thêm** điểm vị trí. Cách này không làm chậm nút SOS vì `resolveSosPosition()` có thể mất tới 10 giây.
- Cả hai bước đều best-effort: `resolveWearableSosPosition` không ném lỗi, `pushLocation` tự nuốt lỗi — hỏng thì cảnh báo vẫn nguyên vẹn, chỉ thiếu bản đồ.
- **Máy ảo Wear OS mặc định không có toạ độ GPS**. Khi demo phải đặt vị trí trong Extended controls → Location; nếu không, đồng hồ sẽ hiện "Không lấy được vị trí đồng hồ" và người nhận chưa có bản đồ.

⚠️ Chưa làm: đẩy vị trí liên tục từ đồng hồ trong lúc cảnh báo còn active (điện thoại làm mỗi 20 giây qua `_startLocationStreaming`). Nghĩa là bản đồ từ đồng hồ hiện **một điểm tĩnh**, không chạy theo người đeo.

**FE đã làm (2026-08-07):** `lib/wear/screens/wear_sensor_sos_screen.dart` — có **cả cảm biến thật** (gia tốc kế qua `FallDetectorService`) **lẫn 3 nút giả lập** (máy ảo không có cảm biến thật, và demo cần bấm ra kết quả ngay). Đếm ngược đúng 20s. `[Hủy báo động]` dùng **`confirm-safety`** chứ không dùng `cancel` — Swagger giới hạn `cancel` cho Trưởng/Phó nhóm, người đeo thường chỉ là thành viên.

**Phụ thuộc cần biết:** đồng hồ cần `deviceId` để gửi event → tài khoản **phải đã ghép wearable từ điện thoại trước**. Chưa ghép thì màn hiện "Chưa ghép thiết bị" và khoá các nút.

**Khác biệt với phát hiện té ngã trên điện thoại:** bản trên điện thoại (`family_shell` + `fall_detector_service`) vẫn gọi `/sos/alerts` với `sourceType: MOBILE_APP` — **không mâu thuẫn**, vì spec này chỉ nói về Wear OS và điện thoại không có `deviceId` wearable.

### [MỚI 2026-08-04] Wearable sensor events — đủ 5 `eventType`, có lịch sử
- `CreateSensorEventDto.eventType` enum đầy đủ: `SOS_BUTTON_PRESSED | FALL_DETECTED | HEART_RATE_ABNORMAL | HARD_IMPACT | ABNORMAL_MOVEMENT`. **`HEART_RATE_ABNORMAL` là giá trị BE mới bổ sung** (bản dump 04/08/2026) — đây cũng là thay đổi **duy nhất** giữa 2 bản dump, số path/operation giữ nguyên 223/290.
- FE trước đây chỉ gửi được 2 loại (`SOS_BUTTON_PRESSED`, `FALL_DETECTED`) bằng 2 nút cứng. Nay màn **Hồ sơ → Thiết bị đeo** có sheet chọn đủ 5 loại, mỗi loại gửi `severity` và `rawValue` hợp nghĩa riêng (`rawValue` là JSON tự do theo mô tả của BE).
- `GET .../wearables/{deviceId}/events` đã wire ở `WearableProvider.fetchEvents` từ trước nhưng **không nơi nào gọi** — lịch sử sự kiện chưa từng hiển thị. Nay có card "Sự kiện cảm biến gần đây" (10 mục gần nhất, tự tải lại sau khi gửi sự kiện test).
- `eventType` lạ (BE thêm mới trước khi FE kịp cập nhật) được hiển thị **nguyên mã gốc** thay vì "Không rõ", để còn đối chiếu được.
- `alertCreated: false` là hành vi hợp lệ — BE chỉ tạo cảnh báo với một số loại/mức độ, hoặc chống duplicate khi đã có SOS active. Nếu duplicate active SOS, BE vẫn trả `alertId` hiện có; UI phải coi đây là đang có alert để người đeo có thể xác nhận an toàn.

### [MỚI 2026-08-04] SOS — `autoCreateAlertFromFall` nay đã hoạt động trên điện thoại
- `UpdateSosSettingsDto.autoCreateAlertFromFall` ("Tự tạo cảnh báo SOS khi thiết bị phát hiện té ngã") **đã có sẵn trong Swagger từ trước**, FE cũng đã parse và có toggle ở màn Cài đặt SOS. Nhưng **trên điện thoại toggle đó không làm gì cả**: chỉ `lib/wear/screens/wear_status_screen.dart` có code nhận biết té ngã, mà màn đó đã không còn nơi nào điều hướng tới sau khi dựng lại giao diện đồng hồ (code chết, `flutter analyze` không bắt được).
- Nay `lib/services/fall_detector_service.dart` hiện thực trên điện thoại bằng gia tốc kép **rơi tự do → va đập** (không phải ngưỡng rung đơn thuần, vì đi xe máy đường xóc cũng vượt ngưỡng rung). `family_shell` bật/tắt detector theo đúng `isEnabled && autoCreateAlertFromFall`, chỉ khi app ở foreground.
- **Cài đặt SOS trước đây chỉ được `GET` khi mở màn Cài đặt SOS.** Shell nay `fetchSettings()` 1 lần sau đăng nhập và mỗi lần app quay lại foreground (không đưa vào chu kỳ poll 15s vì cài đặt gần như không đổi).
- ⚠️ **Lệch cần BE quyết**: `CreateSosAlertDto.sourceType` chỉ có `MOBILE_APP | WEARABLE | SIMULATED_DEVICE` — **không có giá trị nào cho cảnh báo do máy tự phát hiện**. FE tạm gửi `MOBILE_APP` và ghi nguồn vào `message` ("Phát hiện té ngã từ điện thoại…"), nghĩa là màn duyệt/lịch sử **không phân biệt được** người tự bấm nút SOS với máy tự phát hiện. Đề xuất thêm `FALL_DETECTION`: xem `DE_XUAT_BE_SOS_FALL_DETECTION_2026-08-04.md`.
- ⚠️ **Cần BE xác nhận (không phải xây)**: BE có bắn push/socket event khi có SOS alert mới hay không, và bắn cho những ai (mọi thành viên, hay chỉ Manager/Deputy theo `notifyAllMembers`). FE đã đủ 3 kênh nhận (FCM `POST /devices/tokens`, Socket.IO `/notifications`, REST poll fallback) — chỉ chờ xác nhận phía gửi.

### [SỬA 2026-08-04] Face suggestions — 3 lệch so với schema chính thức
Schema chính thức trong OpenAPI: `DetectedFaceSuggestionResponseDto` (`faceId`, `detectionId`, `faceIndex`, `boundingBox`, `detectionScore`, `qualityScore`, **`status: MATCHED | UNMATCHED | SUPERSEDED`**, `candidates[]`) và `FaceSuggestionCandidateResponseDto` (`suggestionId`, `memberId`, `displayName`, `avatarUrl`, `score` 0..1, `secondBestScore`, `scoreMargin`, **`status: PENDING | CONFIRMED | REJECTED | EXPIRED`**, **`permissions { canConfirm, canReject }`** — cả 2 field permissions đều `required`).

- **`EXPIRED` không được tính là đã xử lý** → gợi ý hết hạn vẫn hiện nút Xác nhận, bấm vào chỉ nhận lỗi. Nay `FaceSuggestion.isResolved` bắt thêm `EXPIRE`.
- **`permissions.canConfirm/canReject` bị bỏ qua hoàn toàn** → nút ✓/✗ luôn bật kể cả khi BE nói không có quyền, bấm là 403. Nay đọc `permissions`; **thiếu field thì fail-open** để BE trả 403 quyết định (giống quyền gỡ tag ở `AlbumTag`).
- **`status` của khuôn mặt bị `status` của candidate đè.** Hai DTO **trùng tên field `status`** nhưng enum khác nhau; bước làm phẳng `{...face, ...candidate}` spread candidate sau nên mất trạng thái khuôn mặt → khuôn mặt `SUPERSEDED` (đã bị lần force rescan mới thay thế) vẫn hiện như gợi ý còn hiệu lực. Nay tách sang key riêng `detectionStatus` trước khi ghép và lọc bằng `isSupersededDetection`.
- 3 lệch trên từng được vá ở commit `e580b97` rồi **bị commit đồng bộ main `f947469` ghi đè mất** (kèm cả test). Đã khôi phục + khoá lại bằng 5 test trong `test/album_face_mapping_test.dart` để lần merge sau không im lặng mất nữa.

### [MỚI 2026-07-29] Face AI chấm điểm từng khuôn mặt
- BE nay **kiểm tra từng face trong ảnh** rồi lấy face có điểm cao nhất để gắn thẻ (ví dụ BE đưa: face1 `0.88`, face2 `0.5` → chọn face1).
- Swagger live đã có `FaceSuggestionsApiResponseDto` và example nhiều khuôn mặt. Confidence example dùng thang `0..1`, khớp `normalizedConfidence`; parser vẫn chấp nhận `0..100` để tương thích dữ liệu cũ.
- Việc BE chọn face điểm cao nhất **không đổi** quy tắc nghiệp vụ đã chốt: tag chính thức chỉ được tạo khi **người dùng bấm Xác nhận**.

### Hỗ trợ chi tiêu (xin tiền) — tên người gửi & lọc `mine`
- **[SỬA 2026-07-29] Tên người gửi trước đây LUÔN hiện "Thành viên".** `SupportRequest.fromJson` chỉ đọc `json['requester']`/`json['user']` và chỉ lấy field **trực tiếp** (`fullName`/`name`) → không khớp khuôn DTO member của BE (`{ id, displayName, user: { fullName } }`), nên rơi về fallback 100% số lần. Nay đọc `requesterMember`/`requester`/`member`/`user` + tầng `user` lồng trong, và giữ `requesterName` **rỗng** khi BE không trả tên để UI còn tra theo `requesterMemberId`. ⚠️ [VERIFY WITH OFFICIAL SOURCE] Swagger **không có response schema** cho support-request nên tên object lồng (`requesterMember`) là suy ra từ khuôn các DTO member khác — cần BE chốt.
- Hệ quả đã sửa: cả 2 màn duyệt của Manager (`wallet_screen` tab "Yêu cầu" và `support_request_screen`) và snackbar sau khi duyệt/từ chối đều từng ghi "cho Thành viên" — duyệt tiền mà không biết cho ai.
- **[SỬA 2026-07-29] Lọc "chỉ hiện yêu cầu của bản thân" ở màn member là no-op.** Điều kiện cũ `requesterName.isNotEmpty` luôn đúng vì parser nhồi sẵn 'Thành viên'. Muốn lọc thật phải dùng query **`mine=true`** của `GET /finance/support-requests` (mặc định `false`). Hiện FE vẫn gọi không kèm `mine`, tức dựa hoàn toàn vào việc BE tự giới hạn theo quyền — cần xác nhận BE có lọc hay không trước khi coi là an toàn.

### Phân bổ số dư quỹ tháng vào mục tiêu
- `GET /finance/financial-goals/surplus-availability?month=&year=` → `{periodMonth, periodYear, totalSurplus, allocatedSurplus, availableSurplus}`; `POST /finance/financial-goals/{goalId}/surplus-allocations {periodMonth, periodYear, amount, note?}`.
- **[MỚI 2026-07-29, wire FE] Lối vào ở màn tổng quan tài chính:** card "Số dư quỹ tháng" → chọn mục tiêu → mở `/manager/goal-detail?goalId=…&surplus=1` (sheet nhập số tiền + kiểm tra `availableSurplus` đã có sẵn ở màn chi tiết mục tiêu, không nhân bản logic). Trước đó chỉ vào được từ màn chi tiết mục tiêu.
- Gate bằng `canManageFinance` (Manager/Deputy) đúng theo ghi chú BE; ẩn card khi gia đình **chưa có mục tiêu ACTIVE** nào vì mở ra cũng không chọn được gì.
- `amount` không được vượt `availableSurplus`; đây là bút toán nội bộ từ số dư quỹ tháng, **không tính là khoản thu mới** trong báo cáo dòng tiền.

### Chat — tìm kiếm & thư viện nội dung
- **[MỚI 2026-07-29, wire FE] Tìm kiếm tin nhắn:** `GET .../conversations/{id}/messages?q=` đã nối tại `ChatSearchScreen` (icon kính lúp trên AppBar chat), debounce 400ms. Kết quả **không nhảy tới tin nhắn** trong khung chat: tin có thể nằm ngoài trang đang tải, muốn nhảy đúng chỗ phải lật cursor tới đó rồi scroll-to-index.
- **Thư viện ảnh/file/liên kết:** BE **không có endpoint riêng** và `GET messages` **không filter theo `messageType`** → FE phải lật cursor nhiều trang rồi tự lọc (`fetchMessageHistory`, giới hạn số trang để không kéo vô hạn). Số tin thực sự quét được hiện trên UI. ⚠️ Đề nghị BE thêm `messageType` vào query của `GET messages`, hoặc endpoint attachments riêng, để bỏ cách lật trang tốn request này.

### Chia quỹ theo mô hình — `POST /families/{familyId}/finance/fund-allocations`
- Body: `amount` *(required, >0)* · `periodMonth` *(required, 1–12)* · `periodYear` *(required)* · `modelId` *(optional; bỏ trống để BE lấy model ACTIVE)* · `note` *(optional)*.
- FE kích hoạt model trước, sau đó cho Manager chọn kỳ và nhập tổng quỹ cần chia.
- Response dùng `items[]` để hiển thị từng hũ: `jarId`, `jarName`, `jarCode`, `allocationPercentage`, `amount`, `ledgerEntryId`.
- **[SỬA 2026-07-28] Khóa chống trùng `409` là `familyId + periodMonth + periodYear` — KHÔNG kèm `modelId`** (Swagger ghi rõ "bat ke modelId"). Mỗi kỳ chỉ chia quỹ **một lần**, đổi sang mô hình khác rồi chia lại vẫn bị `409 FUND_ALLOCATION_ALREADY_EXISTS`. Ghi chú cũ "model + kỳ" đã sai → thông báo lỗi FE đã sửa theo khóa mới, nếu không user sẽ tưởng đổi mô hình là chia lại được.
- **[MỚI 2026-07-28] 3 field ở cấp allocation**: `createdAt`, `createdByMemberId`, `note` (có cả trong POST và GET history). BE bổ sung sau khi FE báo `entries[].createdAt` trả null/rỗng lúc runtime — vậy nên **đọc `createdAt` ở cấp allocation, không đọc trong `entries[]`**. Dữ liệu legacy có thể null (kèm `model`/`totalAmount` null) nên UI phải chịu được thiếu.
- `GET /finance/fund-allocations` sort **mới nhất trước** theo `createdAt`; filter `modelId`, `periodMonth`, `periodYear` (2 field kỳ phải truyền **cùng nhau**, thiếu một cái là `400`), `page`, `limit`.
- Ledger entry của chia quỹ có `entryType = ADJUSTMENT` + `sourceType = MODEL_FUND_ALLOCATION`, chỉ để audit. `LedgerEntry.signedAmount` trả **0** cho các entry này — nếu tính như thu nhập thì mỗi lần chia quỹ sẽ làm tổng quỹ phình lên đúng bằng số tiền chia.
- Handle: `400` model thiếu hũ/tổng tỷ lệ khác 100% (`INVALID_JAR_PERCENTAGE`) hoặc vượt quỹ khả dụng (`INSUFFICIENT_AVAILABLE_FUND`); `404` không có model ACTIVE/modelId sai; `409` kỳ đã chia. `401` thiếu/hết token; `403` `FAMILY_MEMBER` hoặc tài khoản chưa verify (chỉ Manager/Deputy đã verify được chia quỹ + activate + xem lịch sử).
- Response `201 Created`, envelope `{success, message, data}`; FE render kết quả chính từ `data.items`. `data.entries` là ledger audit.
- Handle theo code ổn định: `INVALID_FINANCE_MODEL`, `INVALID_JAR_PERCENTAGE`, `INSUFFICIENT_AVAILABLE_FUND`, `NO_ACTIVE_FINANCE_MODEL`, `FUND_ALLOCATION_ALREADY_EXISTS`.
- **[Cập nhật BE 2026-08-10]** Error `INSUFFICIENT_AVAILABLE_FUND` nay trả
  thêm `requestedAmount`, `availableAmount`, `periodMonth`, `periodYear`.
  `ApiException.details` giữ các field này để banner AI nêu chính xác số tiền
  yêu cầu, quỹ còn lại và kỳ bị từ chối.
- **[Cập nhật BE 2026-08-10]** `FUND_ALLOCATION_ALREADY_EXISTS` dùng message
  chuẩn: `Kỳ này đã có lần chia quỹ.`
- FE chỉ chặn `amount` vượt số dư khi đã tải được quỹ khả dụng; BE vẫn phải validate số dư ở server để chống request trực tiếp/race condition.
- Đây là phân loại nội bộ tiền hiện có. Ledger entry sinh ra có `entryType=ADJUSTMENT`, `sourceType=MODEL_FUND_ALLOCATION`; FE giữ để audit nhưng không cộng/trừ khỏi tổng quỹ.

### Lịch sử chia quỹ — `GET /families/{familyId}/finance/fund-allocations`
- Filter: `modelId`, cặp `periodMonth + periodYear`, `page`, `limit`.
- Chỉ `FAMILY_MANAGER` và `DEPUTY_MEMBER`; Member nhận `403`.
- Mỗi item giữ snapshot model/hũ/tỷ lệ/số tiền tại thời điểm chia, nên FE không dựng lại lịch sử từ cấu hình model hiện tại.
- Khóa trùng hiện hành: `familyId + periodMonth + periodYear`. Đổi model vẫn không được chia lại cùng kỳ. Toàn bộ thao tác POST chạy atomic; lỗi một ledger entry sẽ rollback toàn bộ.

### CreateFinanceCategoryDto
- `name` *(required)* · `categoryType`: `INCOME | EXPENSE` *(required)* · `essentialType`: `ESSENTIAL | NON_ESSENTIAL | NEUTRAL` (default `NEUTRAL`)

### CreateSpendingSupportRequestDto
- `amount`: number *(required, >0)* · `purpose`: string *(required)* · `categoryId`: uuid

### CreateLedgerEntryDto
- `entryType`: `INCOME | EXPENSE | CONTRIBUTION | ALLOWANCE | REWARD | SUPPORT | ADJUSTMENT` *(required)* · `amount`: number *(required, >0)* · `description` *(required)* · `entryDate` *(required)* · `note` · `categoryId` · `jarId` · `sourceType` · `sourceId`

> ℹ️ **Finance direction**: dùng `signedAmount` + `entryType` để suy dấu, KHÔNG dựa `amount > 0` (mọi `amount` đều dương). Entry type quyết định thu/chi.

### CreateFinancialGoalDto
- `goalName` *(required)* · `targetAmount`: number *(required, >0)* · `deadline` · `monthlyContributionTarget` · `relatedJarId`

### CreateBudgetPlanDto / CreateBudgetLineDto
- Plan: `planName`, `periodType`, `periodStart`, `periodEnd` *(required)* · `expectedSharedIncome`, `expectedSharedExpense`, `lines[]`
- Line: `plannedAmount` *(required)* · `categoryId`, `jarId`, `thresholdAmount`, `thresholdPercent`, `essentialType`, `note`

### CreateTaskDto / CreateRecurringTaskDto
- Task: `title` *(required)* · `description`, `taskCategoryId`, `taskType` (`AD_HOC` default), `priority`, `status`, `dueAt`
- Recurring: `title` *(required)*, `schedule` *(required, TaskScheduleDto)* · `description`, `taskCategoryId`, `priority`, `status`
- TaskScheduleDto: `repeatType` (`DAILY | WEEKLY | MONTHLY`) *(required)*, `repeatInterval` *(required)*, `startDate` *(required)*, `endDate?`, `dayOfWeek?` (ISO 1=Thứ Hai…7=CN), `status?`

### CreateTaskAssignmentDto / ReassignTaskDto
- `assignedToMemberId` *(required)* · `startAt`, `dueAt`

### CreateTaskSubmissionDto / TaskProofDto
- Submission: `proofs[]` *(required)*, `submissionNote?`
- Proof: `proofType` (`IMAGE | VIDEO | NOTE | FILE`) *(required)*, `fileUrl?`, `thumbnailUrl?`, `note?`

### CreateRewardSettingDto
- `rewardType`: `MONEY_RECORD | POINT | OTHER` *(required)* · `rewardAmount`, `rewardDescription`, `autoCreateSettlement` (default true)

---

## 📌 Ghi chú kỹ thuật
- **Auth**: mọi endpoint (trừ `GET /invitations/{token}` public) cần `Authorization: Bearer {accessToken}`. FE auto-refresh (401 → `/auth/refresh` → retry).
- **Family context**: hầu hết path `/families/{familyId}/...`; lấy `familyId` từ `/families/my`.
- **Response format**: BE wrap `{ success, data, message? }` — FE auto-unwrap.
- **Pagination**: `?page=&limit=` (finance/task list) — cursor-based chưa dùng.
- **Verify gate**: chưa verify email → `POST /families` trả 403. Luồng đăng ký cần chèn OTP verify.

---

## Contract cập nhật 19/08/2026 (BE thông báo, **chưa push** lúc FE dựng sẵn)

FE đã dựng theo lối **nhận cả hai**: ưu tiên field mới, giữ đường cũ làm lưới đỡ
để bản build hiện tại chạy được cả trước lẫn sau khi BE deploy. Khi đã verify
live trên bản BE mới thì bỏ dần các nhánh lưới đỡ được đánh dấu bên dưới.

### Calendar — trạng thái phản hồi của chính người gọi

- `GET .../calendar/events` và `GET .../calendar/events/{eventId}` trả thêm:
  - `myResponseStatus`: `INVITED | ACCEPTED | DECLINED | MAYBE | null`
  - `myParticipant`: `CalendarEventParticipant | null`
- Member không nằm trong `participants` ⇒ cả hai field đều `null`.
- `participants[]` giữ nguyên, không breaking.
- `POST .../calendar/events/{eventId}/respond` trả **event đã cập nhật ở
  top-level của `data`** (không còn bọc trong `data.event`).

FE (`calendar_provider.dart`): `FamilyCalendarEvent.fromJson` đọc
`myResponseStatus` → `responseStatus` (tên cũ) → `myParticipant.responseStatus`.
`respond()` parse event trong response và thay thẳng vào `events`.

> ⚠️ **`INVITED` không phải "đã phản hồi"** — nghĩa là đã được mời nhưng chưa
> trả lời. `normalizeResponseStatus()` quy về `null`; để lọt ra UI thì chip nhỏ
> hiện "Chưa phản hồi" thay vì "Chưa" và nút phản hồi trông như đã chọn.

> 🪜 *Lưới đỡ còn giữ*: quét `participants[]` tìm phần tử của chính mình, và bản
> giữ tạm phản hồi trong `_pendingResponses`. Cả hai chỉ chạy khi field phẳng
> vắng mặt nên tự tắt khi BE lên.

### Task — nộp bài quá hạn

```json
{ "statusCode": 400, "code": "SUBMISSION_OVERDUE",
  "errorCode": "SUBMISSION_OVERDUE",
  "message": "Assignment is overdue and cannot accept submissions" }
```

FE bắt theo **mã** (`submitProofErrorMessage` trong `task_provider.dart`), không
dò chuỗi message vì message gốc là tiếng Anh. `ApiClient` đã gom `code` và
`errorCode` về cùng một chỗ.

FE **không tự chặn** nộp trễ — chỉ cảnh báo trong sheet và để BE trả 400 quyết
định. Xem `DE_XUAT_BE_TASK_QUA_HAN_2026-08-19.md`.

### Album — tag có id trực tiếp

- Media detail/list trả `tags: []`; mỗi tag có `taggedMemberId` và
  `taggedByMemberId` trực tiếp. Endpoint `/tags` cũng trả 2 field này.
- Swagger đã bổ sung schema cho tag, media response và face-scan
  request/retry/status.

FE: `AlbumTag.fromJson` đọc thẳng 2 field. `hasAnyTag` ở `AlbumFaceSection` vẫn
đếm `tags.length` chứ không suy từ id — đúng ngữ nghĩa hơn và không phụ thuộc
BE trả id hay không.

> 🪜 *Lưới đỡ còn giữ*: chuỗi `memberId / userId / taggedMember.id / user.id`
> trong `AlbumTag.fromJson`, vì response đo trên máy thật 19/08 sáng KHÔNG có id
> nào cả.
