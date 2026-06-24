# Family Care Mobile - Latest AI Handoff

Last updated: 2026-06-24
Branch: `NDuy`
Latest commit: `a0a1bea Wire invitation approval flow and task calendar`
Backend Swagger: `http://103.110.84.66/api/docs-json`
API base in app: `http://103.110.84.66/api/v1`

## Current Status

This Flutter project has already been wired to the backend Swagger for the main available modules. Do not restart from mock data unless the backend endpoint is missing from Swagger.

Important: the live Swagger differs from the older local `family-care-api.json` in the invitation flow:

- Old local spec had `POST /invitations/{token}/accept`
- Live Swagger has `POST /invitations/{token}/claim`
- Live Swagger also has manager approval endpoints:
  - `GET /families/{familyId}/invitations?status=CLAIMED`
  - `POST /families/{familyId}/invitations/{id}/approve`
  - `POST /families/{familyId}/invitations/{id}/reject`

## Completed API Wiring

### Auth and Session

- Login/register/logout/refresh/me are wired.
- Tokens are persisted with `SharedPreferences`.
- `ApiClient` sends `Authorization: Bearer <token>`.
- `ApiClient` unwraps backend envelope `{ success, message, data }`.
- `ApiClient` retries once on `401` with refresh token.

Main files:

- `lib/services/api_client.dart`
- `lib/providers/auth_provider.dart`
- `lib/models/user.dart`

### Role and Route Flow

Family role is parsed from `familyRole`:

- `FAMILY_MANAGER` -> manager
- `DEPUTY_MEMBER` -> deputy
- `FAMILY_MEMBER` -> member

Permissions are derived from role in `AppUser`:

- Manager/Deputy can access manager workspace.
- Manager/Deputy can manage finance/tasks/SOS.
- Manager can invite/manage members/subscription.
- Member is routed to member workspace.

Router guards prevent manager/member from entering the wrong shell.

Main files:

- `lib/models/user.dart`
- `lib/navigation/app_router.dart`
- `lib/navigation/manager_shell.dart`
- `lib/navigation/member_shell.dart`

### Family and Invitation Flow

Family APIs are wired:

- Create family
- Fetch family detail and members
- Update family
- Remove member
- Create invitation
- Lookup invite by token
- Claim invite by token
- Manager list claimed invitations
- Manager approve/reject join request

Important current flow:

1. Manager creates invite link.
2. Invitee opens `/invite/:token`.
3. If logged out, invitee is sent to login/register with pending token.
4. Logged-in invitee calls `POST /invitations/{token}/claim`.
5. Invitee waits for approval.
6. Manager opens Profile -> `Yeu cau cho duyet`.
7. Manager approves/rejects with family-scoped invitation endpoints.

Main files:

- `lib/providers/family_provider.dart`
- `lib/screens/auth/invitation_screen.dart`
- `lib/screens/shared/profile_screen.dart`

### Finance

Finance provider has methods for available Swagger endpoints:

- Overview
- Ledger entries
- Support requests and review/cancel
- Finance model templates/models
- Finance jars/funds
- Categories
- Budget plans and budget lines
- Budget plan reports
- Financial goals
- Goal progress and allocations
- Finance alerts
- Monthly finance for current member
- Finance reports

Main files:

- `lib/providers/finance_provider.dart`
- `lib/providers/wallet_provider.dart`
- `lib/providers/money_provider.dart`
- `lib/screens/shared/monthly_finance_screen.dart`
- `lib/screens/shared/finance_model_screen.dart`
- `lib/screens/shared/finance_plans_screen.dart`
- `lib/screens/shared/budget_plan_detail_screen.dart`
- `lib/screens/parent/wallet_screen.dart`
- `lib/screens/child/child_wallet_screen.dart`

### Task and Reward / Score Flow

Task APIs are wired:

- Task categories
- Create/update/cancel task
- Recurring tasks and schedules
- Assign/reassign/start/cancel assignments
- My assignments
- Submit completion with proof
- Upload proof file
- Review submission
- Reward settings
- Reward settlement records
- Mark reward paid externally
- Member confirms reward received
- Reward disputes
- Task unavailability
- Allocate reward settlement to finance jar/goal

Current score/reward status:

- Real reward settlement flow is implemented against backend APIs.
- Child task progress is computed from real task status.
- There is no separate XP/score/gamification endpoint in live Swagger, so do not invent one.
- If asked to finish "score flow", continue from reward settlement/task completion first, then only add XP if BE adds an endpoint.

Main files:

- `lib/providers/task_provider.dart`
- `lib/screens/parent/task_management_screen.dart`
- `lib/screens/child/child_tasks_screen.dart`
- `lib/screens/child/child_home_screen.dart`

### Calendar

Live Swagger does not expose a standalone calendar event endpoint.

Current implementation:

- `CalendarScreen` is no longer a placeholder.
- It uses `TaskProvider.fetchTasks()`.
- It maps task `dueDate/startAt` onto month/day cells.
- It shows task list by selected day.

Main file:

- `lib/screens/parent/calendar_screen.dart`

### SOS

SOS APIs are wired:

- Create alert
- Fetch alerts
- Fetch alert detail
- Respond to alert
- Confirm safety
- Send location to alert
- Resolve/cancel alert

UI includes:

- Active SOS banner
- SOS detail screen
- Notification route into SOS detail when reference exists

Main files:

- `lib/providers/sos_provider.dart`
- `lib/widgets/active_sos_banner.dart`
- `lib/screens/shared/sos_screen.dart`
- `lib/screens/shared/sos_alert_detail_screen.dart`

### Notifications

Notification APIs are wired:

- Fetch family notifications
- Mark one notification as read
- Mark all as read

Notification tap routing:

- Task notification -> task screen
- Finance notification -> finance/wallet screen
- SOS notification -> SOS detail if reference is available

Main files:

- `lib/providers/notification_provider.dart`
- `lib/screens/shared/notifications_screen.dart`

### Subscription

Subscription/plans/checkout provider wiring exists.

Main file:

- `lib/providers/subscription_provider.dart`

## Backend Gaps - Do Not Fake API Calls

Live Swagger currently does not expose real endpoints for:

- Chat
- Album/photo
- AI assistant
- Standalone calendar events
- Normal GPS/location sharing outside active SOS
- Wearable pairing/device SOS settings
- Separate XP/score gamification

For these modules, either keep local placeholder UI or wait for backend endpoints.

## Project Notes

- `file.zip` was moved out of the project to `D:\Desktop\file.zip`.
- Do not commit generated ZIP files inside the project.
- There are many pre-existing dirty files in the working tree. Be careful to stage only files related to the current task.
- The latest local commit `a0a1bea` includes:
  - Invitation claim/approval flow
  - Manager pending invitation approval UI
  - Task-backed calendar screen

## Verification Notes

`dart format`, `dart --version`, and `flutter analyze --no-pub` were attempted but the Dart/Flutter process hung on this machine. If the toolchain is fixed, run:

```powershell
dart format lib
flutter analyze --no-pub
```

If `git push origin NDuy` hangs at `git-remote-https`, check GitHub credential manager/token login.

## Next Suggested Work

1. Continue with any unfinished finance UI screens against existing `FinanceProvider`.
2. Improve reward/score UX using existing task reward settlement APIs.
3. Only add XP/score API calls after backend exposes a Swagger endpoint.
4. Keep committing after each completed flow/API module.
