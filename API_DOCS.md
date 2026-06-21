# API Backend Analysis — Family Care
**Server:** http://103.110.84.66/api/v1
**Date:** 2026-06-21 (re-verified trực tiếp qua `GET /api/docs-json`)

## Endpoints (145 operations / 107 paths total)

### Auth
- `POST /api/v1/auth/register` � Register a new account (default role: FAMILY_MANAGER)
- `POST /api/v1/auth/login` � Authenticate with email & password
- `POST /api/v1/auth/refresh` � Rotate the token pair using a valid refresh token
- `POST /api/v1/auth/logout` � Log out. Pass refreshToken to revoke only this device, omit to revoke all
- `GET /api/v1/auth/me` � Get the currently authenticated user

### Families
- `POST /api/v1/families` � Create a family (creator becomes MANAGER)
- `GET /api/v1/families/my` � List families the current user belongs to
- `GET /api/v1/families/{familyId}` � Get a family (members only)
- `PATCH /api/v1/families/{familyId}` � Update a family (family MANAGER only)
- `DELETE /api/v1/families/{familyId}/members/{userId}` � Remove a member from the family (MANAGER only)

### Finance
- `GET /api/v1/families/{familyId}/finance/monthly-finances/me` � Lấy thông tin tài chính tháng của thành viên hiện tại
- `POST /api/v1/families/{familyId}/finance/monthly-finances/me` � Tạo thông tin tài chính tháng cho thành viên hiện tại
- `PUT /api/v1/families/{familyId}/finance/monthly-finances/me` � Cập nhật thông tin tài chính tháng của thành viên hiện tại
- `GET /api/v1/families/{familyId}/finance/model-templates` � Lấy các mẫu mô hình tài chính có sẵn trong hệ thống
- `GET /api/v1/families/{familyId}/finance/models` � Lấy mô hình tài chính; thành viên thường chỉ thấy mô hình đang hoạt động
- `POST /api/v1/families/{familyId}/finance/models` � Tạo mô hình tài chính và các hũ mặc định cho mô hình chuẩn
- `PATCH /api/v1/families/{familyId}/finance/models/{modelId}/activate` � Kích hoạt mô hình tài chính và vô hiệu hóa mô hình cũ
- `GET /api/v1/families/{familyId}/finance/jars` � Lấy hũ tài chính; thành viên thường chỉ thấy hũ của mô hình đang hoạt động
- `POST /api/v1/families/{familyId}/finance/jars` � Tạo hũ tài chính thuộc một mô hình của gia đình
- `PATCH /api/v1/families/{familyId}/finance/jars/{jarId}` � Cập nhật hũ tài chính của gia đình
- `GET /api/v1/families/{familyId}/finance/categories` � Lấy danh sách danh mục tài chính của gia đình
- `POST /api/v1/families/{familyId}/finance/categories` � Tạo danh mục tài chính cho gia đình
- `GET /api/v1/families/{familyId}/finance/support-requests` � Lấy danh sách yêu cầu hỗ trợ chi tiêu có thể xem
- `POST /api/v1/families/{familyId}/finance/support-requests` � Tạo yêu cầu hỗ trợ chi tiêu cho bản thân
- `GET /api/v1/families/{familyId}/finance/support-requests/{requestId}` � Lấy chi tiết yêu cầu hỗ trợ chi tiêu
- `PATCH /api/v1/families/{familyId}/finance/support-requests/{requestId}/review` � Phê duyệt hoặc từ chối yêu cầu hỗ trợ chi tiêu
- `PATCH /api/v1/families/{familyId}/finance/support-requests/{requestId}/cancel` � Hủy yêu cầu hỗ trợ chi tiêu đang chờ của bản thân
- `GET /api/v1/families/{familyId}/finance/alerts` � Lấy danh sách cảnh báo tài chính có thể xem
- `GET /api/v1/families/{familyId}/finance/alerts/{alertId}` � Lấy chi tiết cảnh báo tài chính
- `POST /api/v1/families/{familyId}/finance/alerts/recompute` � Tính lại cảnh báo ngân sách và mục tiêu tài chính
- `PATCH /api/v1/families/{familyId}/finance/alerts/{alertId}/acknowledge` � Xác nhận đã xem cảnh báo tài chính
- `PATCH /api/v1/families/{familyId}/finance/alerts/{alertId}/resolve` � Đánh dấu cảnh báo tài chính đã được giải quyết
- `GET /api/v1/families/{familyId}/finance/reports/overview` � Lấy báo cáo tổng quan tài chính gia đình
- `GET /api/v1/families/{familyId}/finance/reports/budget-goal` � Lấy báo cáo ngân sách, mục tiêu và cảnh báo
- `GET /api/v1/families/{familyId}/finance/reports/non-essential-spending` � Lấy báo cáo chi tiêu không thiết yếu
- `GET /api/v1/families/{familyId}/finance/financial-goals` � Lấy danh sách mục tiêu tài chính có thể xem
- `POST /api/v1/families/{familyId}/finance/financial-goals` � Tạo mục tiêu tài chính gia đình
- `GET /api/v1/families/{familyId}/finance/financial-goals/{goalId}` � Lấy chi tiết và tiến độ mục tiêu tài chính
- `PATCH /api/v1/families/{familyId}/finance/financial-goals/{goalId}` � Cập nhật mục tiêu tài chính gia đình
- `PATCH /api/v1/families/{familyId}/finance/financial-goals/{goalId}/cancel` � Hủy mục tiêu tài chính gia đình
- `GET /api/v1/families/{familyId}/finance/financial-goals/{goalId}/progress` � Lấy tiến độ tính toán của mục tiêu tài chính
- `GET /api/v1/families/{familyId}/finance/financial-goals/{goalId}/allocations` � Lấy các giao dịch đã phân bổ vào mục tiêu
- `POST /api/v1/families/{familyId}/finance/financial-goals/{goalId}/allocations` � Phân bổ một phần giao dịch vào mục tiêu tài chính
- `PATCH /api/v1/families/{familyId}/finance/goal-allocations/{allocationId}` � Cập nhật số tiền phân bổ vào mục tiêu
- `DELETE /api/v1/families/{familyId}/finance/goal-allocations/{allocationId}` � Xóa phân bổ khỏi mục tiêu tài chính
- `GET /api/v1/families/{familyId}/finance/budget-plans` � Lấy danh sách kế hoạch ngân sách của gia đình
- `POST /api/v1/families/{familyId}/finance/budget-plans` � Tạo kế hoạch ngân sách ở trạng thái DRAFT
- `GET /api/v1/families/{familyId}/finance/budget-plans/{budgetPlanId}` � Lấy chi tiết kế hoạch ngân sách
- `PATCH /api/v1/families/{familyId}/finance/budget-plans/{budgetPlanId}` � Cập nhật kế hoạch ngân sách đang ở trạng thái DRAFT
- `PATCH /api/v1/families/{familyId}/finance/budget-plans/{budgetPlanId}/activate` � Kích hoạt kế hoạch ngân sách
- `PATCH /api/v1/families/{familyId}/finance/budget-plans/{budgetPlanId}/close` � Đóng kế hoạch ngân sách đang hoạt động
- `PATCH /api/v1/families/{familyId}/finance/budget-plans/{budgetPlanId}/cancel` � Hủy kế hoạch ngân sách DRAFT hoặc ACTIVE
- `GET /api/v1/families/{familyId}/finance/budget-plans/{budgetPlanId}/report` � Lấy báo cáo planned-vs-actual của kế hoạch ngân sách
- `POST /api/v1/families/{familyId}/finance/budget-plans/{budgetPlanId}/lines` � Thêm dòng vào kế hoạch ngân sách DRAFT
- `PATCH /api/v1/families/{familyId}/finance/budget-lines/{budgetLineId}` � Cập nhật dòng ngân sách thuộc kế hoạch DRAFT
- `DELETE /api/v1/families/{familyId}/finance/budget-lines/{budgetLineId}` � Xóa dòng ngân sách thuộc kế hoạch DRAFT
- `GET /api/v1/families/{familyId}/finance/ledger/entries` � Lấy danh sách giao dịch trong sổ tài chính chung
- `POST /api/v1/families/{familyId}/finance/ledger/entries` � Tạo giao dịch nội bộ trong sổ tài chính chung của gia đình
- `GET /api/v1/families/{familyId}/finance/overview` � Lấy tổng quan sổ tài chính chung và thông tin tháng của thành viên hiện tại

### Tasks (45 operations — đã verify khớp với `task_provider.dart`)
- `GET /api/v1/families/{familyId}/tasks` — Lấy danh sách công việc của gia đình
- `POST /api/v1/families/{familyId}/tasks` — Tạo công việc cơ bản cho gia đình
- `GET /api/v1/families/{familyId}/tasks/{taskId}` — Lấy chi tiết công việc
- `PATCH /api/v1/families/{familyId}/tasks/{taskId}` — Cập nhật công việc cơ bản
- `PATCH /api/v1/families/{familyId}/tasks/{taskId}/cancel` — Hủy công việc
- `POST /api/v1/families/{familyId}/tasks/recurring` — Tạo công việc lặp lại
- `GET /api/v1/families/{familyId}/tasks/{taskId}/schedule` — Lấy lịch lặp của công việc
- `PATCH /api/v1/families/{familyId}/tasks/{taskId}/schedule` — Cập nhật lịch lặp
- `POST /api/v1/families/{familyId}/tasks/{taskId}/schedule/generate-assignments` — Sinh phân công thủ công
- `GET /api/v1/families/{familyId}/tasks/categories` — Danh sách danh mục công việc
- `POST /api/v1/families/{familyId}/tasks/categories` — Tạo danh mục công việc
- `PATCH /api/v1/families/{familyId}/tasks/categories/{categoryId}` — Cập nhật danh mục công việc
- `POST /api/v1/families/{familyId}/tasks/{taskId}/assignments` — Giao công việc cho thành viên
- `GET /api/v1/families/{familyId}/tasks/{taskId}/assignments` — Danh sách phân công của một công việc
- `GET /api/v1/families/{familyId}/tasks/my-assignments` — Công việc được giao cho thành viên hiện tại
- `GET /api/v1/families/{familyId}/tasks/assignments/{assignmentId}` — Chi tiết phân công
- `PATCH /api/v1/families/{familyId}/tasks/assignments/{assignmentId}/start` — Bắt đầu thực hiện
- `PATCH /api/v1/families/{familyId}/tasks/assignments/{assignmentId}/cancel` — Hủy phân công
- `PATCH /api/v1/families/{familyId}/tasks/assignments/{assignmentId}/reassign` — Giao lại cho thành viên khác
- `POST /api/v1/families/{familyId}/tasks/assignments/{assignmentId}/submissions` — Nộp minh chứng hoàn thành
- `GET /api/v1/families/{familyId}/tasks/assignments/{assignmentId}/submissions` — Danh sách minh chứng của một phân công
- `GET /api/v1/families/{familyId}/tasks/submissions/{submissionId}` — Chi tiết minh chứng
- `PATCH /api/v1/families/{familyId}/tasks/submissions/{submissionId}/review` — Duyệt/từ chối minh chứng
- `POST /api/v1/families/{familyId}/tasks/proofs/upload` — Upload file minh chứng (multipart)
- `PATCH /api/v1/families/{familyId}/tasks/proofs/{proofId}` — Cập nhật minh chứng đã nộp
- `DELETE /api/v1/families/{familyId}/tasks/proofs/{proofId}` — Xóa minh chứng đã nộp
- `POST /api/v1/families/{familyId}/tasks/assignments/{assignmentId}/unavailability` — Báo không thể làm công việc
- `GET /api/v1/families/{familyId}/tasks/unavailabilities` — Danh sách báo cáo không thể làm
- `GET /api/v1/families/{familyId}/tasks/unavailabilities/{unavailabilityId}` — Chi tiết báo cáo
- `PATCH /api/v1/families/{familyId}/tasks/unavailabilities/{unavailabilityId}/cancel` — Hủy báo cáo
- `PATCH /api/v1/families/{familyId}/tasks/unavailabilities/{unavailabilityId}/handle` — Xử lý báo cáo
- `POST /api/v1/families/{familyId}/tasks/{taskId}/reward-setting` — Tạo cấu hình thưởng
- `GET /api/v1/families/{familyId}/tasks/{taskId}/reward-setting` — Lấy cấu hình thưởng
- `PATCH /api/v1/families/{familyId}/tasks/{taskId}/reward-setting` — Cập nhật cấu hình thưởng
- `DELETE /api/v1/families/{familyId}/tasks/{taskId}/reward-setting` — Xóa cấu hình thưởng
- `POST /api/v1/families/{familyId}/tasks/submissions/{submissionId}/reward-settlement` — Tạo ghi nhận thưởng
- `GET /api/v1/families/{familyId}/tasks/reward-settlements` — Danh sách ghi nhận thưởng
- `GET /api/v1/families/{familyId}/tasks/reward-settlements/{settlementId}` — Chi tiết ghi nhận thưởng
- `PATCH /api/v1/families/{familyId}/tasks/reward-settlements/{settlementId}/mark-paid` — Ghi nhận đã trả thưởng ngoài hệ thống
- `PATCH /api/v1/families/{familyId}/tasks/reward-settlements/{settlementId}/confirm-received` — Xác nhận đã nhận thưởng
- `PATCH /api/v1/families/{familyId}/tasks/reward-settlements/{settlementId}/cancel` — Hủy ghi nhận thưởng
- `POST /api/v1/families/{familyId}/tasks/reward-settlements/{settlementId}/allocations` — Phân bổ thưởng vào quỹ/mục tiêu
- `GET /api/v1/families/{familyId}/tasks/reward-settlements/{settlementId}/allocations` — Danh sách phân bổ thưởng
- `POST /api/v1/families/{familyId}/tasks/reward-settlements/{settlementId}/disputes` — Báo chưa nhận được thưởng
- `GET /api/v1/families/{familyId}/tasks/reward-disputes` — Danh sách tranh chấp thưởng
- `GET /api/v1/families/{familyId}/tasks/reward-disputes/{disputeId}` — Chi tiết tranh chấp
- `PATCH /api/v1/families/{familyId}/tasks/reward-disputes/{disputeId}/resolve` — Xử lý tranh chấp

### SOS (8 operations)
> ⚠️ FE trước đây gọi sai path (`/sos` thay vì `/families/{familyId}/sos/alerts`) — đã sửa trong `sos_provider.dart` ngày 2026-06-21.
- `POST /api/v1/families/{familyId}/sos/alerts` — Kích hoạt cảnh báo SOS (mọi thành viên). Body: `CreateSosAlertDto { sourceType, severity?, initialLatitude?, initialLongitude?, message? }`
- `GET /api/v1/families/{familyId}/sos/alerts` — Lịch sử cảnh báo SOS của gia đình (query: `status`)
- `GET /api/v1/families/{familyId}/sos/alerts/{alertId}` — Chi tiết một cảnh báo (kèm phản hồi + vị trí)
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/locations` — Gửi điểm vị trí cho cảnh báo đang active. Body: `PushSosLocationDto { latitude, longitude, sourceType, accuracy?, recordedAt?, deviceId? }`
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/responses` — Phản hồi cảnh báo. Body: `CreateSosResponseDto { responseType: VIEWED|CONFIRM_SAFE|NEED_HELP, message? }`
- `POST /api/v1/families/{familyId}/sos/alerts/{alertId}/confirm-safety` — Người kích hoạt tự xác nhận an toàn
- `PATCH /api/v1/families/{familyId}/sos/alerts/{alertId}/resolve` — Resolve cảnh báo (FAMILY_MANAGER/DEPUTY_MEMBER). Body: `ResolveSosAlertDto { resolutionNote? }`
- `PATCH /api/v1/families/{familyId}/sos/alerts/{alertId}/cancel` — Hủy cảnh báo (FAMILY_MANAGER/DEPUTY_MEMBER). Body: `ResolveSosAlertDto { resolutionNote? }`

### Invitations
- `POST /api/v1/families/{familyId}/invitations` � Invite a member to a family (FAMILY_MANAGER only)
- `GET /api/v1/invitations/{token}` � Look up an invitation by token (public)
- `POST /api/v1/invitations/{token}/accept` � Accept an invitation (joins the family)
- `POST /api/v1/invitations/{token}/reject` � Reject an invitation

### Admin - Subscription Plans
- `POST /api/v1/admin/subscription-plans` � Create a subscription plan (SYSTEM_ADMIN only)
- `GET /api/v1/admin/subscription-plans` � List subscription plans (paginated, incl. inactive)
- `GET /api/v1/admin/subscription-plans/{id}` � Get a subscription plan by id
- `PATCH /api/v1/admin/subscription-plans/{id}` � Update a subscription plan
- `DELETE /api/v1/admin/subscription-plans/{id}` � Delete a subscription plan

### Subscription Plans
- `GET /api/v1/subscription-plans` � List active subscription plans (for subscribers)

### Admin - Users
- `GET /api/v1/admin/users` � List users (paginated, SYSTEM_ADMIN only)
- `GET /api/v1/admin/users/{id}` � Get a user by id
- `PATCH /api/v1/admin/users/{id}` � Update a user (status/type/profile)
- `DELETE /api/v1/admin/users/{id}` � Delete a user

### Admin - Families
- `GET /api/v1/admin/families` � List families (paginated, SYSTEM_ADMIN only)
- `GET /api/v1/admin/families/{id}` � Get a family by id (with members)
- `PATCH /api/v1/admin/families/{id}` � Update a family
- `DELETE /api/v1/admin/families/{id}` � Delete a family (cascades members + invitations)

### Admin - Invitations
- `GET /api/v1/admin/invitations` � List invitations (paginated, SYSTEM_ADMIN only)
- `GET /api/v1/admin/invitations/{id}` � Get an invitation by id
- `PATCH /api/v1/admin/invitations/{id}` � Update an invitation status
- `DELETE /api/v1/admin/invitations/{id}` � Delete an invitation

### Admin - Family Members
- `GET /api/v1/admin/family-members` � List family members (paginated, SYSTEM_ADMIN only)
- `GET /api/v1/admin/family-members/{id}` � Get a family member by id
- `PATCH /api/v1/admin/family-members/{id}` � Update a family member (role/relationship/status)
- `DELETE /api/v1/admin/family-members/{id}` � Remove a family member

## Request Schemas

### RegisterDto
- `email`: string *(required)*
- `password`: string *(required)*
- `fullName`: string
- `phone`: string
- `avatarUrl`: string

### LoginDto
- `email`: string *(required)*
- `password`: string *(required)*

### RefreshTokenDto
- `refreshToken`: string *(required)*

### LogoutDto
- `refreshToken`: string

### CreateFamilyDto
- `name`: string *(required)*
- `description`: string
- `avatarUrl`: string
- `relationship`: string

### UpdateFamilyDto
- `name`: string
- `description`: string
- `avatarUrl`: string

### CreateMemberMonthlyFinanceDto
- `periodMonth`: number *(required)*
- `periodYear`: number *(required)*
- `expectedIncome`: object
- `actualIncome`: object
- `expectedPersonalExpense`: object
- `actualPersonalExpense`: object
- `incomeVisibility`: string
- `expenseVisibility`: string
- `note`: object

### UpdateMemberMonthlyFinanceDto
- `periodMonth`: number *(required)*
- `periodYear`: number *(required)*
- `expectedIncome`: object
- `actualIncome`: object
- `expectedPersonalExpense`: object
- `actualPersonalExpense`: object
- `incomeVisibility`: string
- `expenseVisibility`: string
- `note`: object

### CreateFinanceModelDto
- `modelType`: string *(required)*
- `name`: string *(required)*

### CreateFinanceJarDto
- `financeModelId`: string *(required)*
- `name`: string *(required)*
- `jarCode`: string *(required)*
- `allocationPercentage`: number *(required)*
- `description`: string
- `isActive`: boolean

### UpdateFinanceJarDto
- `name`: string
- `jarCode`: string
- `allocationPercentage`: number
- `description`: object
- `isActive`: boolean

### CreateFinanceCategoryDto
- `name`: string *(required)*
- `categoryType`: string *(required)*
- `essentialType`: string

### CreateSpendingSupportRequestDto
- `amount`: number *(required)*
- `categoryId`: string
- `purpose`: string *(required)*

### ReviewSpendingSupportRequestDto
- `decision`: string *(required)*
- `decisionNote`: string
- `occurredAt`: string

### RecomputeBudgetAlertsDto
- `budgetPlanId`: string
- `goalId`: string
- `periodStart`: string
- `periodEnd`: string
- `scope`: string

### ResolveBudgetAlertDto
- `note`: string

### CreateFinancialGoalDto
- `goalName`: string *(required)*
- `targetAmount`: number *(required)*
- `deadline`: string
- `monthlyContributionTarget`: number
- `relatedJarId`: string

### UpdateFinancialGoalDto
- `goalName`: string
- `targetAmount`: number
- `deadline`: object
- `monthlyContributionTarget`: object
- `relatedJarId`: object

### CreateGoalAllocationDto
- `ledgerEntryId`: string *(required)*
- `amount`: number *(required)*

### UpdateGoalAllocationDto
- `amount`: number *(required)*

### CreateBudgetLineDto
- `categoryId`: string
- `jarId`: string
- `plannedAmount`: number *(required)*
- `thresholdAmount`: number
- `thresholdPercent`: number
- `essentialType`: string
- `note`: string

### CreateBudgetPlanDto
- `planName`: string *(required)*
- `periodType`: string *(required)*
- `periodStart`: string *(required)*
- `periodEnd`: string *(required)*
- `expectedSharedIncome`: number
- `expectedSharedExpense`: number
- `lines`: array

### UpdateBudgetPlanDto
- `planName`: string
- `periodType`: string
- `periodStart`: string
- `periodEnd`: string
- `expectedSharedIncome`: object
- `expectedSharedExpense`: object

### UpdateBudgetLineDto
- `categoryId`: object
- `jarId`: object
- `plannedAmount`: number
- `thresholdAmount`: object
- `thresholdPercent`: object
- `essentialType`: string
- `note`: object

### CreateLedgerEntryDto
- `entryType`: string *(required)*
- `amount`: number *(required)*
- `description`: string *(required)*
- `note`: string
- `entryDate`: string *(required)*
- `categoryId`: string
- `sourceType`: string
- `sourceId`: string

### CreateInvitationDto
- `email`: string *(required)*
- `invitedPhone`: string
- `familyRole`: string
- `relationship`: string

### CreateSubscriptionPlanDto
- `planCode`: string *(required)*
- `name`: string *(required)*
- `annualPrice`: number *(required)*
- `maxMembers`: number *(required)*
- `storageLimit`: number *(required)*
- `featureAccess`: object
- `isActive`: boolean

### UpdateSubscriptionPlanDto
- `planCode`: string
- `name`: string
- `annualPrice`: number
- `maxMembers`: number
- `storageLimit`: number
- `featureAccess`: object
- `isActive`: boolean

### AdminUpdateUserDto
- `accountStatus`: string
- `userType`: string
- `verificationStatus`: string
- `fullName`: string
- `phone`: string
- `avatarUrl`: string

### AdminUpdateFamilyDto
- `name`: string
- `description`: string
- `avatarUrl`: string
- `status`: string
- `activationStatus`: string

### AdminUpdateInvitationDto
- `status`: string *(required)*

### AdminUpdateMemberDto
- `familyRole`: string
- `relationship`: string
- `status`: string
- `displayName`: string

