# API Backend Analysis — Family Care
**Server:** https://api.familycare-digital.com/api/v1
**Swagger UI:** https://api.familycare-digital.com/api/docs
**Date:** snapshot 2026-07-07 (118 paths) → **re-verify 2026-07-11 với swagger mới: 147 paths / 188 operations**. FE wiring audit toàn diện 2026-07-08, đối chiếu swagger 07/11 sau merge main.

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
> Vẫn CHƯA có (0 endpoint): Location tracking độc lập, `PATCH /auth/me`, role endpoint user-facing (UC18), Calendar `/events`, Album, AI, FCM token.

---

## Endpoints

### Auth
- `POST /api/v1/auth/register` — Register a new account (default role: FAMILY_MANAGER). 409 nếu email đã tồn tại.
- `POST /api/v1/auth/login` — Authenticate with email & password. 401 sai thông tin, 403 account bị khóa.
- `POST /api/v1/auth/refresh` — Rotate token pair bằng refresh token hợp lệ.
- `POST /api/v1/auth/logout` — Log out. Có `refreshToken` → revoke đúng device; bỏ trống → revoke tất cả.
- `GET /api/v1/auth/me` — Lấy user đang đăng nhập. **(Vẫn chỉ có GET, chưa có PATCH.)**
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

### SOS (10 operations — khớp `sos_provider.dart`; +2 endpoint mới 07/11)
- `POST /api/v1/families/{familyId}/sos/alerts` — Kích hoạt SOS (mọi thành viên). Body `CreateSosAlertDto { sourceType, severity?, initialLatitude?, initialLongitude?, message? }`.
  - `sourceType`: `MOBILE_APP | WEARABLE | SIMULATED_DEVICE` (default `MOBILE_APP`)
  - `severity`: `LOW | MEDIUM | HIGH | CRITICAL`
- `GET /api/v1/families/{familyId}/sos/alerts` — Lịch sử SOS. Query `status`: `ACTIVE | RESOLVED | CANCELED | FALSE_ALARM`.
- `GET /api/v1/families/{familyId}/sos/alerts/{alertId}` — Chi tiết 1 alert (kèm phản hồi + vị trí). **[wire FE 2026-07-08]** icon ℹ️ trên alert card → `_SosAlertDetailSheet` (`JsonReportView`).
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/locations` — Gửi 1 điểm vị trí cho alert active. Body `PushSosLocationDto { latitude, longitude, sourceType, accuracy?, recordedAt?, deviceId? }`. **[wire FE 2026-07-07]** `SOSScreen._startLocationStreaming()` — gọi mỗi 20s từ lúc gửi SOS thành công tới khi confirm-safety.
  - `sourceType`: `MOBILE_GPS | WEARABLE_GPS | SIMULATED_GPS`
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/locations/batch` — **[MỚI 07/11]** Gửi NHIỀU điểm 1 lần. Body `PushSosLocationBatchDto { points: PushSosLocationDto[] }`. **[wire FE]** `SosProvider.pushLocationBatch()` — dùng cho buffer offline (đã có method, **chưa nối UI trigger**).
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
- `messageType`: `TEXT | IMAGE | FILE | LOCATION | SOS_QUICK_MESSAGE`. `[VERIFY]` giới hạn `limit`, encode emoji URL, có nên chuyển WS realtime.
- ✅ **Tin an toàn nhanh (2026-07-13, verify live)**: FE gửi `messageType: SOS_QUICK_MESSAGE` tường minh trong `SendMessageDto` — nút khiên cạnh ô nhập chat mở sheet 4 tin mẫu, bubble hiển thị nổi bật màu cam kèm nhãn "TIN AN TOÀN". BE echo đúng `messageType` trong response (đã test server thật).

### Notifications — **[MỚI, bỏ mock]**
- `GET /api/v1/families/{familyId}/notifications` — Danh sách thông báo của thành viên hiện tại. Query `unreadOnly` (bool).
- `PATCH /api/v1/families/{familyId}/notifications/read-all` — Đánh dấu tất cả đã đọc.
- `PATCH /api/v1/families/{familyId}/notifications/{notificationId}/read` — Đánh dấu 1 thông báo đã đọc.

> ⚠️ Vẫn CHƯA có `POST /auth/fcm-token` → **push notification (FCM) chưa làm được**, chỉ in-app notification qua REST.

### Subscriptions — **[MỚI, checkout thật]**
- `GET /api/v1/families/{familyId}/subscription` — Xem gói hiện tại của gia đình.
- `POST /api/v1/families/{familyId}/subscription/checkout` — Tạo liên kết thanh toán Stripe để nâng gói. Body `CreateCheckoutDto { planCode }`.
  - `planCode` là gói **trả phí** (không phải FREE). Giá trị chuẩn: `PLUS`, `PREMIUM` (+ có thể có mã custom như `GOLD`).
  - `[VERIFY]` Response schema (field `checkoutUrl` / `url` / `sessionId`?) — spec không mô tả body response. Xác nhận với Nghĩa.
  - `[VERIFY]` Luồng chọn FREE (downgrade/cancel) có gọi endpoint này không.
  - ✅ **UX hạ gói (2026-07-13)**: FE so sánh `priceValue` (annualPrice) với gói đang dùng — gói rẻ hơn hiển thị CTA "Hạ xuống {tên gói}" + dialog xác nhận trước khi checkout (thay vì "Nâng cấp Free" gây hiểu lầm). Hành vi backend khi checkout FREE vẫn chờ `[VERIFY]` ở trên.

### Finance — Monthly Finance (cá nhân)
- `GET /api/v1/families/{familyId}/finance/monthly-finances/me` — Tài chính tháng của bản thân. **Query `month` & `year` BẮT BUỘC.**
- `POST /api/v1/families/{familyId}/finance/monthly-finances/me` — Tạo. Body `CreateMemberMonthlyFinanceDto`. 409 nếu tháng đã tồn tại.
- `PUT /api/v1/families/{familyId}/finance/monthly-finances/me` — Cập nhật. Body `UpdateMemberMonthlyFinanceDto`. 404 nếu chưa khai báo.
  - DTO có thêm `expectedSharedContribution` / `actualSharedContribution` (nullable), `incomeVisibility` / `expenseVisibility` (`PRIVATE | FAMILY`).

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

### Finance — Spending Support Requests
- `GET /api/v1/families/{familyId}/finance/support-requests` — Danh sách. Query: `page, limit, status, requesterMemberId, categoryId, fromDate, toDate, mine`.
  - `status`: `PENDING | APPROVED | REJECTED | CANCELED`.
- `POST /api/v1/families/{familyId}/finance/support-requests` — Tạo yêu cầu cho bản thân. Body `CreateSpendingSupportRequestDto { amount, purpose, categoryId? }`.
- `GET /api/v1/families/{familyId}/finance/support-requests/{requestId}` — Chi tiết. **[wire FE 2026-07-08]** tap vào `_RequestCard` → `_RequestDetailSheet` (`JsonReportView`).
- `PATCH /api/v1/families/{familyId}/finance/support-requests/{requestId}/review` — Duyệt/từ chối. Body `ReviewSpendingSupportRequestDto { decision, decisionNote?, occurredAt? }` (`decision`: `APPROVE | REJECT`).
- `PATCH /api/v1/families/{familyId}/finance/support-requests/{requestId}/cancel` — Hủy yêu cầu PENDING của bản thân.

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
  - `[VERIFY]` Response schema của cả 3 report **không được Swagger document** (chỉ có mô tả ngắn) — FE render bằng `JsonReportView` (key-value đệ quy, generic) để không đoán sai tên field. Cần chạy thật với data thật để xác nhận field names, sau đó có thể nâng cấp UI structured hơn.

### Finance — Financial Goals
- `GET /api/v1/families/{familyId}/finance/financial-goals` — Danh sách. Query: `page, limit, status, relatedJarId, includeProgress`. `status`: `ACTIVE | ACHIEVED | CANCELED | AT_RISK`.
- `POST /api/v1/families/{familyId}/finance/financial-goals` — Tạo mục tiêu. Body `CreateFinancialGoalDto { goalName, targetAmount, deadline?, monthlyContributionTarget?, relatedJarId? }`.
- `GET /api/v1/families/{familyId}/finance/financial-goals/{goalId}` — Chi tiết + tiến độ. **[wire FE 2026-07-08]** `GoalDetailScreen` (`/manager/goal-detail?goalId=`).
- `PATCH /api/v1/families/{familyId}/finance/financial-goals/{goalId}` — Cập nhật. **[wire FE 2026-07-08]** nút sửa trong `GoalDetailScreen`.
- `PATCH /api/v1/families/{familyId}/finance/financial-goals/{goalId}/cancel` — Hủy mục tiêu.
- `GET /api/v1/families/{familyId}/finance/financial-goals/{goalId}/progress` — Tiến độ tính toán. **[wire FE 2026-07-08]** `GoalDetailScreen` mục "Tiến độ chi tiết" (`JsonReportView`, schema không document).

### Finance — Goal Contribution Plans — **[wire FE 2026-07-07]**
- `GET .../financial-goals/{goalId}/contribution-suggestions` — Gợi ý đóng góp/tháng theo từng thành viên. Query `month`, `year` (bắt buộc).
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
