## Overview

Báo cáo phân tích tiến độ FE Mobile với API mới ngày 2026-07-27.

Phạm vi kiểm tra:
- Đồng bộ Git với `origin/main` của repo `16-Doffy/SEP-Family-Care-Mobile`.
- Face AI Service: validate ảnh trước khi enroll Face Profile.
- AI Chatbot: pending action và confirm/reject action.
- Finance Module: finance home, reports, monthly finance, ledger, category, goal, support request.
- Admin update: tác động tới mobile.

## Prerequisites

- Repo local: `C:\Users\giaph\Desktop\Family Care\SEP-Family-Care-Mobile`
- Branch local hiện tại: `giap`
- Remote: `https://github.com/16-Doffy/SEP-Family-Care-Mobile.git`
- OpenAPI mới: file đính kèm `pasted-text.txt`
- Lệnh đã chạy:

```powershell
git fetch origin main
git status --short --branch
git log --oneline --decorate --left-right HEAD...origin/main
git diff --name-only HEAD origin/main
flutter analyze
```

## Steps

1. Kiểm tra remote và branch local.
2. Fetch `origin/main`.
3. So sánh `HEAD` với `origin/main`.
4. Tìm endpoint/API mới trong code FE.
5. Đối chiếu với OpenAPI mới và ghi chú BE.
6. Chạy `flutter analyze` để kiểm tra tình trạng build/static analysis.

## Expected Result

### 1. Git Sync

Kết quả:
- `HEAD`, `origin/main`, `origin/giap`, `main`, `origin/HEAD` đang cùng commit:
  `2c2bf4c chore(finance): an child_wallet design cua minh - dung ban main (Duy) de tranh xung dot merge`
- Không có commit khác biệt giữa local branch `giap` và `origin/main`.
- Không có file diff giữa `HEAD` và `origin/main`.
- Không có thay đổi local cần merge.

Kết luận: không có update mới từ phía FE Duy/Tyrant trên `main` để kéo về thêm tại thời điểm kiểm tra.

### 2. Face AI Service

Trạng thái hiện tại sau chỉnh sửa: đã wire flow validate trước enroll theo hướng best-effort, không chặn vận hành nếu BE chưa bật endpoint mới.

Đã có:
- `FaceProfileProvider.validate()` gọi `POST /families/:familyId/face-profiles/:memberId/validate`.
- Model parse phòng thủ `results[]`, `canEnroll`, `reasonCode`.
- UI `MemberDetailScreen` và `AlbumPeopleScreen` chỉ cho đăng ký khi validate trả `canEnroll=true`.
- Nếu API validate trả `404/405/501`, FE hiển thị cảnh báo và fallback sang luồng enroll hiện tại để người dùng vẫn đăng ký Face Profile được.
- UI hiển thị trạng thái từng ảnh bằng badge/chip: chờ kiểm tra, đạt, lỗi.
- UI hiển thị lỗi theo `reasonCode`:
  - `NO_FACE_DETECTED`
  - `MULTIPLE_FACES_DETECTED`
  - `MIME_MISMATCH`
  - `IMAGE_TOO_LARGE`
- `FaceProfileProvider.enroll()` upload multipart field `files`, 3-5 ảnh.
- Enroll gửi `consentConfirmed=true`.
- UI `MemberDetailScreen` và `AlbumPeopleScreen` đã chặn số lượng ảnh 3-5 và yêu cầu consent.

⚠️ [VERIFY WITH OFFICIAL SOURCE]
OpenAPI đính kèm có endpoint validate và multipart `files` min 3/max 5, nhưng response 201 chưa có schema DTO cho `results[]/canEnroll/reasonCode`. Cần BE bổ sung response sample vào Swagger để FE parse chuẩn.

### 3. AI Chatbot Pending Action

Trạng thái hiện tại sau chỉnh sửa: đã wire API chính và reload module sau confirm.

Đã có:
- Model `AiPendingAction` đọc `pendingAction.preview`, `expiresAt`, `status`.
- Provider gọi:
  - `POST /messages/:messageId/confirm-action`
  - `POST /messages/:messageId/reject-action`
- UI render card xác nhận/hủy.
- Error mapping đã có cho 403, 409, 410.
- `CREATE_CALENDAR_EVENT` đã có label riêng.
- Card xác nhận đã có icon/màu/trạng thái/preview theo từng action type.
- Sau `confirm-action`, FE reload module tương ứng:
  - `CREATE_TASK` -> reload task list.
  - `CREATE_LEDGER_ENTRY` -> reload finance ledger/overview.
  - `CREATE_CALENDAR_EVENT` -> reload calendar events.
- UI ưu tiên `action.messageId` nếu BE trả field này riêng trong `pendingAction`.

### 4. Finance Module

Trạng thái hiện tại: phần lớn đã đồng bộ với API mới.

Đã có:
- Finance home gọi:
  - `/finance/summary`
  - `/finance/cash-flow-summary`
  - `/finance/category-spending-summary`
  - `/finance/member-contribution-summary`
- UI Finance home đã render thành 4 vùng theo contract mới: tổng quan, dòng tiền vào-ra, chi tiêu theo danh mục, đóng góp theo thành viên.
- Có fallback về `/finance/overview` nếu `/summary` fail.
- Ledger đã có list/create/detail/patch/delete.
- Category đã có create/update/delete.
- Monthly finance đã có:
  - `/monthly-finances/me`
  - `/monthly-finances/members/:memberId`
  - `/monthly-summary/me`
  - `/monthly-summary/members/:memberId`
- Financial goals đã dùng `GET /financial-goals/:goalId` cho detail/progress, không còn gọi `/progress` deprecated trong `GoalDetailScreen`.
- Contribution plan đã có confirm/submit/approve/reject và shortage/plans/suggestions.
- Support request đã có list/create/detail/review/cancel.

Cần theo dõi:
- Timestamp chưa migration sang UTC thật. FE giữ semantic cũ `localIsoMs()` cho các flow support request review và hiển thị ledger để tránh đổi hành vi khi BE chưa xác nhận. `utcIsoMs()` chỉ để sẵn cho field nào BE chốt nhận UTC thật.
- Support request list không filter `mine`; BE đã xác nhận member thường chỉ thấy request của chính họ, nên FE có thể chấp nhận. Nếu BE thay đổi behavior, cần thêm query/filter theo role.

### 5. Admin Update

Trạng thái hiện tại: không ảnh hưởng trực tiếp Mobile.

- Mobile không có UI gọi `/admin/users/:id`.
- `userType` chỉ được parse trong model `User` để phân biệt `SYSTEM_ADMIN`, không thấy FE Mobile gửi PATCH admin update user.
- Rule "không update userType qua PATCH /admin/users/:id" thuộc scope Admin Web/BE, không phải mobile flow hiện tại.

### 6. Static Analysis

`flutter analyze` chạy xong và trả về 26 issues mức `info`, không thấy lỗi compile/error.

Nhóm issue:
- `curly_braces_in_flow_control_structures`
- `use_build_context_synchronously`
- `deprecated_member_use` với Radio API mới
- `unnecessary_import`
- `prefer_initializing_formals`
- `use_null_aware_elements`

Đây là tech debt/lint cleanup, không phải blocker API mới.

### 7. UI Polish Theo Đề Xuất

Đã bổ sung lớp design-system nền:
- `AppSpacing`, `AppRadius`, `AppShadows`, `AppStatusColors`.
- `AppCard` cho card có surface/shadow/ripple thống nhất.
- `StatusBadge` cho chip trạng thái.
- `AppBottomSheetScaffold` cho bottom sheet có drag handle/title/subtitle/action thống nhất.
- `RetryState` dùng lại `EmptyState` cho lỗi có nút thử lại.

Đã áp dụng:
- Wallet/Finance dùng `SkeletonList`, `RetryState`, `AppCard` cho loading/error/card chính.
- Support Request dùng `SkeletonList`, `RetryState`, `EmptyState`, `AppCard`, `StatusBadge`, và `AppBottomSheetScaffold` cho detail sheet.
- Bottom Navigation có active indicator dạng pill, ripple/tap feedback, SOS badge/glow rõ hơn, surface theo theme để cải thiện dark mode.

## Troubleshooting

### Ưu tiên P0

1. Implement Face Profile validate trước enroll: đã hoàn tất theo hướng best-effort, có fallback nếu BE chưa support endpoint.

2. Yêu cầu BE bổ sung response schema validate vào Swagger.

### Ưu tiên P1

1. Hoàn thiện AI pending action: đã hoàn tất phần FE.

2. Chuẩn hóa timestamp: tạm hoãn migration call site sang UTC thật; cần BE xác nhận contract trước khi đổi semantic.

### Ưu tiên P2

1. Dọn lint `flutter analyze` để giảm noise trước khi release.
2. Cập nhật `API_DOCS.md` thêm endpoint Face validate và trạng thái response schema chưa đầy đủ.
