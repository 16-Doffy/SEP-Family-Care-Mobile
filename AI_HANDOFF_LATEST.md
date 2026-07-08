# Family Care Mobile — AI Handoff (Latest)

Last updated: **2026-06-24**
Branch: `NDuy`
Latest commit: `8208cd2 Restore finance allocation UX and Vietnamese labels`
Backend Swagger (live): `http://103.110.84.66/api/docs-json`
API base in app: `http://103.110.84.66/api/v1`

---

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── user.dart
│   └── money_request.dart
├── navigation/
│   ├── app_router.dart
│   ├── manager_shell.dart
│   └── member_shell.dart
├── providers/
│   ├── auth_provider.dart
│   ├── family_provider.dart
│   ├── finance_provider.dart
│   ├── gps_provider.dart
│   ├── money_provider.dart
│   ├── notification_provider.dart
│   ├── sos_provider.dart
│   ├── subscription_provider.dart
│   ├── task_provider.dart
│   └── wallet_provider.dart
├── screens/
│   ├── auth/
│   │   ├── create_family_screen.dart
│   │   ├── invitation_screen.dart
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── child/
│   │   ├── child_home_screen.dart
│   │   ├── child_tasks_screen.dart
│   │   └── child_wallet_screen.dart
│   ├── parent/
│   │   ├── calendar_screen.dart
│   │   ├── home_dashboard_screen.dart
│   │   ├── task_management_screen.dart
│   │   └── wallet_screen.dart
│   └── shared/
│       ├── ai_assistant_screen.dart
│       ├── album_screen.dart
│       ├── budget_plan_detail_screen.dart
│       ├── chat_screen.dart
│       ├── finance_model_screen.dart
│       ├── finance_plans_screen.dart
│       ├── monthly_finance_screen.dart
│       ├── notifications_screen.dart
│       ├── profile_screen.dart
│       ├── sos_alert_detail_screen.dart
│       └── sos_screen.dart
├── services/
│   └── api_client.dart
├── theme/
│   ├── app_colors.dart
│   └── app_theme.dart
└── widgets/
    ├── active_sos_banner.dart
    ├── avatar_widget.dart
    ├── request_money_sheet.dart
    ├── ring_chart.dart
    └── waffle_chart.dart
```

---

## Current Status — What Is Wired

Do not restart from mock data unless the backend endpoint is explicitly missing from live Swagger.

### Auth & Session

- Login / register / logout / refresh / me — wired.
- Tokens persisted in `SharedPreferences`.
- `ApiClient` sends `Authorization: Bearer <token>` and retries once on 401 with refresh token.
- `ApiClient` unwraps backend envelope `{ success, message, data }`.

Key files: `lib/services/api_client.dart`, `lib/providers/auth_provider.dart`, `lib/models/user.dart`

---

### Role & Route Flow

Family role is parsed from the `familyRole` field returned by `/auth/me`:

| `familyRole` value | Internal role | Access |
|---|---|---|
| `FAMILY_MANAGER` | `manager` | Manager shell + all permissions |
| `DEPUTY_MEMBER` | `deputy` | Manager shell + most permissions |
| `FAMILY_MEMBER` | `member` | Member shell |

Permissions are computed in `AppUser`:
- `canManageTasks`, `canManageSharedFinance`, `canResolveSos`, `canInviteMembers`, `canManageFamilyMembers`, `canManageFamilySettings`

Router guards prevent cross-shell navigation.

Key files: `lib/models/user.dart`, `lib/navigation/app_router.dart`, `lib/navigation/manager_shell.dart`, `lib/navigation/member_shell.dart`

---

### Family & Invitation Flow

Wired endpoints:
- GET/PATCH `/families/{id}`
- DELETE `/families/{id}/members/{userId}`
- POST `/families/{id}/invitations`
- GET `/invitations/{token}` (lookup)
- POST `/invitations/{token}/claim` ← live Swagger (not `/accept`)
- GET `/families/{id}/invitations?status=CLAIMED`
- POST `/families/{id}/invitations/{id}/approve`
- POST `/families/{id}/invitations/{id}/reject`

Invitation flow:
1. Manager creates invite → gets link with token.
2. Invitee opens `/invite/:token`, calls `claim`.
3. Manager approves in Profile → "Yêu cầu chờ duyệt".

`family_provider.dart` also exposes `roleLabel` which returns `'Trưởng nhóm'` / `'Phó nhóm'` / `'Thành viên'`.

Key files: `lib/providers/family_provider.dart`, `lib/screens/auth/invitation_screen.dart`, `lib/screens/shared/profile_screen.dart`

---

### Finance

Finance provider covers all available Swagger endpoints:

- Overview, ledger entries, income/expense recording
- Support requests (create / review / cancel)
- Finance model templates and jars/funds
- Categories, budget plans, budget lines, plan reports
- Financial goals, goal progress, goal allocations
- Finance alerts
- Monthly finance for current member (`/monthly-finances/me`)
- Finance reports

Member finance tab shows personal monthly finance + support requests — **not** the family fund balance (no such endpoint in Swagger).

Active jars: use `financeProvider.activeJars` (filtered from `jars`, not raw model jars).

Key files: `lib/providers/finance_provider.dart`, `lib/providers/wallet_provider.dart`, `lib/providers/money_provider.dart`, `lib/screens/parent/wallet_screen.dart`, `lib/screens/shared/monthly_finance_screen.dart`, `lib/screens/shared/finance_model_screen.dart`, `lib/screens/shared/finance_plans_screen.dart`, `lib/screens/shared/budget_plan_detail_screen.dart`

---

### Tasks & Reward/Score Flow

Wired endpoints:
- Task categories
- Create / update / cancel task
- Recurring tasks and schedules
- Assign / reassign / start / cancel assignments
- My assignments (`/assignments/me`)
- Submit completion with proof upload
- Review submission (approve/reject)
- Reward settings
- Reward settlement records
- Mark reward paid externally
- Member confirms reward received
- Reward disputes
- Task unavailability
- Allocate reward settlement to finance jar/goal

Score/XP: computed from real task status (DONE count). There is **no XP/gamification endpoint** in live Swagger — do not invent one.

Key files: `lib/providers/task_provider.dart`, `lib/screens/parent/task_management_screen.dart`, `lib/screens/child/child_tasks_screen.dart`, `lib/screens/child/child_home_screen.dart`

---

### Calendar

No standalone calendar event endpoint in live Swagger.

`CalendarScreen` uses `TaskProvider.fetchTasks()` and maps `task.dueDate / task.startAt` onto month/day cells. Selecting a day shows task list for that day.

Key file: `lib/screens/parent/calendar_screen.dart`

---

### SOS

Wired endpoints:
- POST create alert, GET alerts, GET alert detail
- POST respond to alert (field: `responseType` — required by `CreateSosResponseDto`)
- POST confirm safety
- POST send location to alert
- POST resolve alert (field: `resolutionNote` — required by `ResolveSosAlertDto`)
- POST cancel alert

UI:
- `ActiveSosBanner` — shows on any screen when active SOS exists; taps to detail.
- `SosAlertDetailScreen` — status/severity badges, quick response chips, confirm safe / resolve / cancel buttons.
- `SosScreen` — trigger SOS.
- SOS notifications route to `SosAlertDetailScreen` if `referenceId` is available.

Quick response chips: `Đã xem` / `Tôi an toàn` / `Cần giúp đỡ`

Key files: `lib/providers/sos_provider.dart`, `lib/widgets/active_sos_banner.dart`, `lib/screens/shared/sos_screen.dart`, `lib/screens/shared/sos_alert_detail_screen.dart`

---

### Notifications

Wired endpoints:
- GET `/families/{id}/notifications`
- PATCH `.../notifications/{id}/read`
- PATCH `.../notifications/read-all`

Tap routing:
- Task/assignment/submission notification → task screen
- Finance notification → wallet/finance screen
- SOS notification → SOS detail (uses `referenceId` or falls back to active alert)

`AppNotification.fromJson` defensively parses many field name variants (`data`, `metadata`, `payload`, `target` sub-objects).

Default title fallback: `'Thông báo'`

Key files: `lib/providers/notification_provider.dart`, `lib/screens/shared/notifications_screen.dart`

---

### Subscription

Subscription / plans / checkout provider exists. No major changes recently.

Key file: `lib/providers/subscription_provider.dart`

---

## Backend Gaps — Do Not Fake API Calls

Live Swagger does **not** expose endpoints for:
- Chat
- Album / photo
- AI assistant
- Standalone calendar events
- GPS/location sharing outside active SOS
- Wearable pairing / device SOS settings
- XP / score / gamification

For these: keep placeholder UI, do not call fake endpoints.

---

## 2026-06-24 — Patch Notes (Current Session)

### Vietnamese Diacritics — Full Pass

All unaccented Vietnamese strings across `lib/` have been fixed (two full scan passes). Files changed:

| File | Changes |
|---|---|
| `lib/widgets/active_sos_banner.dart` | Cảnh báo SOS đang hoạt động, Chưa tìm thấy mã cảnh báo SOS, Bấm để xem |
| `lib/screens/parent/calendar_screen.dart` | Lịch gia đình, Tháng, Công việc ngày, Không có công việc nào |
| `lib/navigation/member_shell.dart` | Trang chủ, Nhiệm vụ, Tôi |
| `lib/providers/notification_provider.dart` | Thông báo (default title), nhiệm vụ (search match) |
| `lib/screens/shared/notifications_screen.dart` | Thông báo (title), Chưa tìm thấy chi tiết cảnh báo SOS, phút trước / giờ trước |
| `lib/screens/shared/profile_screen.dart` | **Full rewrite** — ~35 strings: Tài khoản, Gia đình, Hồ sơ cá nhân, TRƯỞNG NHÓM, THÀNH VIÊN, Gửi lời mời, Cài đặt gia đình, Đã cập nhật gia đình, v.v. |
| `lib/screens/auth/register_screen.dart` | Tạo tài khoản, Tên gia đình, Gia đình Nguyễn, Mật khẩu, Đăng ký, v.v. |
| `lib/screens/shared/sos_alert_detail_screen.dart` | **Full rewrite** — ~20 strings: Chi tiết SOS, Giải quyết cảnh báo SOS, Đã xác nhận an toàn, Người gửi, Vị trí, v.v. |
| `lib/providers/family_provider.dart` | Trưởng nhóm, Phó nhóm (roleLabel) |
| `lib/screens/parent/task_management_screen.dart` | Không tải được minh chứng nộp bài cho assignment này |

### File Cleanup

Deleted from project root:
- `PENDING_API.md` — mô tả vấn đề cũ đã fix (task endpoint, calendar hardcode, v.v.), thay bằng file này
- `FAMILY_CARE_HANDOFF.md` — tài liệu tạm để apply code từ zip, đã apply xong
- `family_care_mobile.iml`, `family_care.iml` — IntelliJ IDE artifacts
- `update_skill.ps1` — script hardcode path máy cũ
- `swagger.json` — API spec cũ (Jun 20), thay bằng `family-care-api.json` (Jun 21)
- `.codex/` — AI tool directory với docs cũ

---

## Previous Patch Notes (2026-06-24 earlier)

- Manager task proof preview parses proof lists/URLs defensively (many field name variants).
- `ApiClient.absoluteUrl()` builds file URLs from API origin.
- Finance support request review is optimistic (remove → restore on failure).
- Finance model screen uses `activeJars` to avoid duplicate jars.
- Reward allocation sheet clarifies flow: records after external payment, not money transfer.
- Goal tab explains: progress changes via ledger/reward allocation, not real transfer.

---

## Verification

`dart format`, `dart analyze`, and `flutter analyze` may hang on this machine. If toolchain is fixed, run:

```powershell
dart format lib
flutter analyze --no-pub
```

Push: `git push origin NDuy` may hang at `git-remote-https` — check GitHub credential manager.

---

## Next Suggested Work

1. Test invitation flow end-to-end on device (claim → manager approval).
2. Test SOS flow: create → respond → confirm safe → resolve.
3. Continue finance UI if any remaining screens need wiring.
4. Commit current working tree changes.
