# API còn thiếu — cần bổ sung

> Base URL: `http://103.110.84.66/api/v1`  
> Auth: `Authorization: Bearer <accessToken>`  
> Response envelope: `{ success, message, data }` — unwrap field `data` (ApiClient đã xử lý tự động)

## Đã xong ✅

| Provider | Endpoint |
|---|---|
| auth | POST /auth/login, /register, /logout, /refresh · GET /auth/me · PATCH /auth/me |
| wallet | GET /families/{id}/finance/overview · GET /families/{id}/finance/ledger/entries · POST (INCOME/EXPENSE) |
| money | GET/POST /families/{id}/finance/support-requests · PATCH .../review · PATCH .../cancel |
| family | GET/PATCH /families/{id} · DELETE /families/{id}/members/{userId} · POST /families/{id}/invitations |
| finance | models, jars, categories, budget-plans, goals, alerts, monthly-finances |

---

## Cần bổ sung ❌

### 1. `task_provider.dart` — sửa endpoint + inject familyId
Hiện đang gọi `/tasks` (sai). Endpoint thật:

```
GET    /families/{familyId}/tasks?status=TODO&assigneeId=...
POST   /families/{familyId}/tasks          body: { title, assigneeId, reward, dueDate }
PATCH  /families/{familyId}/tasks/{id}     body: { status: 'DONE'|'REJECTED' }
DELETE /families/{familyId}/tasks/{id}
```

Cần thêm `set familyId(String id)` giống WalletProvider, rồi đăng ký `ChangeNotifierProxyProvider` trong `main.dart`.

---

### 2. `child_home_screen.dart` — XP, tasks, chart đang hardcode

File: `lib/screens/child/child_home_screen.dart`

```dart
const _barData = [40, 80, 60, 100, 75, 50, 90]; // hardcode
const _xp = 360;                                 // hardcode
final _tasks = [_TaskItem('1', 'Dọn phòng ngủ', ...)]; // hardcode
```

Cần watch TaskProvider để lấy tasks thật. XP/level chưa có endpoint — giữ tạm hoặc tính từ tasks DONE.

---

### 3. `calendar_screen.dart` — events hardcode

File: `lib/screens/parent/calendar_screen.dart`

```dart
static const _events = <int, List<...>>{
  3: [(title: 'Khám sức khỏe định kỳ', ...)],  // hardcode
  ...
};
```

Endpoint cần gọi:
```
GET /families/{familyId}/tasks?month=6&year=2026
```
Map task theo `dueDate` vào calendar. Nếu BE không có events riêng thì dùng tasks làm sự kiện.

---

### 4. `notifications_screen.dart` — hardcode hoàn toàn

File: `lib/screens/shared/notifications_screen.dart`

Danh sách `notifs` đang viết tay. BE có thể có endpoint thông báo — cần confirm với BE team.  
Tạm thời có thể dùng `finance.newAlerts` từ FinanceProvider.

---

### 5. `chat_screen.dart` — không có BE

File: `lib/screens/shared/chat_screen.dart`

Swagger hiện **không có** chat endpoint. Giữ nguyên local state hoặc xác nhận BE team có bổ sung.

---

### 6. `album_screen.dart` — không có BE

File: `lib/screens/shared/album_screen.dart`

Swagger **không có** album/photo endpoint. Giữ UI mock hoặc confirm với BE.

---

### 7. `gps_provider.dart` + `sos_provider.dart` — sai familyId scope

Hiện gọi `/location/family` và `/sos/...` — endpoint có đúng không cần xác nhận với BE (Swagger không thấy rõ).  
Nếu đúng path thì chỉ cần inject familyId tương tự các provider khác.

---

## Hướng bổ sung nhanh nhất

1. Fix `task_provider.dart` endpoint + ProxyProvider (quan trọng nhất, tasks hiện thị ở nhiều screen)
2. Wire `child_home_screen` + `task_management_screen` vào TaskProvider thật
3. Wire `calendar_screen` lấy tasks theo tháng
4. Xác nhận BE có endpoint notifications chưa → bổ sung provider
5. Chat + Album: confirm BE rồi làm sau
