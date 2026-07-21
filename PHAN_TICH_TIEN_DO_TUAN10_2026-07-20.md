# Phân tích tiến độ FE Mobile — Tuần 10 (20/07/2026)

**Người thực hiện:** Giáp (SE171532) — FE Mobile (Flutter)
**Nguồn đối chiếu:** `SEP-Family-Care-Mobile` (branch `giap`) vs `Family_Care_DOC/Tuần 10/docs-json.json` (Swagger prod)
**So sánh với:** `family-care-api.json` (snapshot 10/07)

---

## 1. Tóm tắt điều hành

| Chỉ số | Giá trị |
|---|---|
| Swagger cũ (10/07) | 150 operations |
| Swagger mới (20/07) | **260 operations** (201 paths, 47 tags) |
| Endpoint **mới thêm** | **121** |
| Endpoint **bị xóa** | **11** (toàn bộ nhóm Invitations) |
| File Dart trong `lib/` | 84 |
| Branch `giap` | **ahead 16 / behind 11** so với `origin/main` |

**3 việc gấp nhất:**

1. **Merge `giap` → `main`** — Duy đã yêu cầu trực tiếp, đang lệch 16/11 commit. Càng để lâu càng khó merge.
2. **Calendar Event** — API đã lên đầy đủ (7 endpoint), FE vẫn là **mock hoàn toàn** (`calendar_screen.dart` dùng `static const _events`).
3. **featureAccess mismatch** — FE đang parse key phẳng (`aiEnabled`, `advancedFinance`), Nhật mô tả key lồng (`calendar.enabled`, `calendar.reminders`). **Không khớp → gating sẽ sai.** `[VERIFY]`

---

## 2. Trạng thái từng module FE Mobile

| Module | Trạng thái | Ghi chú |
|---|---|---|
| Auth | ✅ Done | Có `forgot-password` / `reset-password`. Mới thêm `POST /auth/firebase` — **chưa nối** |
| Finance (ledger, budget, goals, jars, alerts) | ✅ Done — API thật | Bao phủ rộng nhất trong app |
| Task & Reward | ✅ Done — API thật | Bao gồm recurring, proof, settlement, dispute |
| Family Management | ✅ Done | Đã chuyển sang `join-requests` + `invite-code` (đúng hướng API mới) |
| SOS | ✅ Done | emergency-contacts, settings, locations/batch, location/current đều đã nối |
| Location / Family Map | ✅ Done | 3 EP location + OSRM routing |
| Notifications | ✅ Done | Socket.IO realtime + REST poll fallback + local notification |
| Push FCM | ⚠️ Đang chặn | Code đã xong (`push_service.dart`), **BE cấp sai `google-services.json`** (package `com.company.familycare` ≠ `com.familycare.family_care`), nghi dùng Legacy FCM API đã ngừng |
| Chat | ✅ Done — API thật | 18 endpoint, đã wire (không còn mock như tài liệu cũ ghi) |
| Album (media/tags/moderation) | ✅ Done | 14 endpoint đã nối |
| **Calendar** | ❌ **Mock 100%** | API đã sẵn sàng — ưu tiên cao nhất |
| **Face AI (Face Profile + Suggestion)** | ❌ **Chưa có gì** | 10 endpoint mới, 0 dòng code FE |
| **Wearables (API server)** | ❌ Chưa nối | Có module `lib/wear/` local nhưng chưa gọi 6 EP `/wearables` |
| Subscription | ⚠️ Một phần | Đọc plan + tạo checkout OK; **gating theo featureAccess chưa làm** |

---

## 3. Thay đổi API cần xử lý ngay

### 3.1 BREAKING — Invitations bị gỡ bỏ hoàn toàn (11 EP)

```
XÓA: GET/POST  /families/{id}/invitations
XÓA: POST      /families/{id}/invitations/{id}/approve | reject
XÓA: GET       /invitations/{token}
XÓA: POST      /invitations/{token}/claim | reject
XÓA: 4 EP admin/invitations
```

**Thay bằng:** `Join Requests` (7 EP) + `invite-code` (2 EP).

✅ **FE đã chuyển đổi xong** — grep `lib/` không còn tham chiếu `invitations`, đang dùng `/join-requests`, `/invite-codes/{code}`, `/families/{id}/invite-code`.
⚠️ Tuy nhiên `invitation_provider.dart` và `invitation_requests_screen.dart` vẫn giữ **tên cũ** → nên đổi tên thành `join_request_*` để tránh nhầm lẫn khi Duy/Nhật đọc code.

### 3.2 Calendar — 7 EP mới, FE chưa dùng

```
GET    /families/{familyId}/calendar/events
POST   /families/{familyId}/calendar/events
GET    /families/{familyId}/calendar/events/{eventId}
PATCH  /families/{familyId}/calendar/events/{eventId}
PATCH  /families/{familyId}/calendar/events/{eventId}/cancel
PATCH  /families/{familyId}/calendar/events/{eventId}/reminder
POST   /families/{familyId}/calendar/events/{eventId}/respond
```

**CreateCalendarEventDto:**

| Field | Kiểu | Bắt buộc |
|---|---|---|
| `title` | string | ✅ |
| `description` | string | |
| `location` | string | |
| `startTime` | string (ISO) | ✅ |
| `endTime` | string (ISO) | |
| `isRecurring` | boolean | |
| `participantMemberIds` | array | |
| `reminderEnabled` | boolean | |

**RespondCalendarEventDto:** `responseStatus` ∈ `ACCEPTED` / `DECLINED` / `MAYBE` (bắt buộc)
**UpdateCalendarReminderDto:** `reminderEnabled: boolean` (bắt buộc)

**Gating theo Nhật:**
- `POST/PATCH/cancel event` → khóa nếu gói không có `calendar.enabled` → BE trả **403**
- `PATCH /reminder` → khóa nếu không có `calendar.reminders`
- `isRecurring = true` → check thêm `calendar.recurringEvents`
- `GET events` → **luôn cho đọc** (không khóa) — user không mất quyền xem dữ liệu cũ khi gói hết hạn
- Khi tạo event, BE tự tạo participants và gửi notification `type = CALENDAR`

> ⚠️ `notification_provider.dart` và `notification_router.dart` đã có nhánh `calendar` — cần verify route đích khi màn Calendar thật ra đời.

### 3.3 Face AI — 10 EP mới (5 Face Profile + 5 Face Suggestion)

```
POST   /families/{familyId}/face-profiles/{memberId}/enroll
GET    /families/{familyId}/face-profiles/{memberId}
DELETE /families/{familyId}/face-profiles/{memberId}
PATCH  /families/{familyId}/face-profiles/{memberId}/enable | disable

POST   /families/{familyId}/albums/media/{mediaId}/face-scan
GET    /families/{familyId}/albums/media/{mediaId}/face-scan
GET    /families/{familyId}/albums/media/{mediaId}/face-suggestions
POST   .../face-suggestions/{suggestionId}/confirm
POST   .../face-suggestions/{suggestionId}/reject
```

**Enroll — `multipart/form-data`:**
- `files`: array binary, **minItems 3, maxItems 5** (⚠️ Nhật nói "2-3 ảnh" trong flow — Swagger yêu cầu **tối thiểu 3**. Lấy theo Swagger.)
- `consentConfirmed`: boolean, **bắt buộc**

**Trả lời câu hỏi của Duy — "nên tạo face profile ở đâu":**
→ `screens/parent/member_detail_screen.dart`, thêm section "Hồ sơ khuôn mặt". Lý do: (1) đúng flow Nhật mô tả, (2) màn này đã có sẵn context `memberId`, (3) enroll là hành động quản trị per-member, không thuộc album.

**Consent:** vì có field `consentConfirmed` bắt buộc, FE **phải** hiện dialog đồng ý sinh trắc học trước khi upload — không được auto-set `true`.

### 3.4 Nhóm khác đáng chú ý

| Nhóm | Số EP mới | Ảnh hưởng FE Mobile |
|---|---|---|
| Admin (Audit/Backup/Docker/Revenue/System…) | 43 | ❌ Không — thuộc Duy (React Dashboard) |
| Chat | 18 | ✅ Đã nối |
| Wearables | 6 | ⚠️ Chưa nối — thuộc scope FE Mobile |
| Finance - contribution plans | 7 | ✅ Đã nối |
| Auth (`/auth/firebase`) | 1 | ⚠️ Chưa nối — social login? `[VERIFY]` |
| Albums media/tags/moderation | 14 | ✅ Đã nối |

---

## 4. Đối chiếu yêu cầu của team

### Nhật (BE)

| # | Yêu cầu | Trạng thái đối chiếu |
|---|---|---|
| 1 | API Calendar Event | ✅ Có trên Swagger (7 EP) — **FE chưa làm** |
| 2 | featureAccess gating theo SubscriptionPlan | ⚠️ **Key không khớp code FE hiện tại** `[VERIFY]` |
| 3 | Notification type `CALENDAR` | ⚠️ Router có nhánh, chưa có màn đích |
| 4 | Face AI service (nâng cấp "mai") | ✅ EP đã có trên Swagger — FE chưa làm |
| 5 | Manage Member Role / Relationship / Deputy permission | ❌ **CHƯA CÓ trên Swagger** — mới là đề xuất |

**Điểm chốt về #5:** quét toàn bộ 201 path, chỉ có `DELETE /families/{familyId}/members/{userId}`. **Không có** EP nào cho:
- Cập nhật `relationship` của member
- Cập nhật role / member role
- Grant / revoke deputy permission
- List member riêng (đang phụ thuộc `GET /families/{id}` detail)

→ FE Mobile **bị chặn** ở chức năng đổi role/deputy. Cần Nhật xác nhận timeline. Đây là blocker cho `member_detail_screen.dart`.

### Duy (FE)

| Yêu cầu | Phản hồi |
|---|---|
| "Làm xong cái nào merge main cái đó" | ⚠️ **Đang ahead 16 / behind 11.** Cần merge ngay — đây là việc số 1 |
| "Nhận diện khuôn mặt qua album theo local storage" | ⚠️ Cần làm rõ: Swagger là **server-side scan** (`POST /face-scan`), không phải local. `[VERIFY]` — nếu ý là cache suggestion xuống local thì OK, nhưng enroll/scan bắt buộc qua BE |
| "Nên tạo face profile ở đâu" | → `member_detail_screen.dart` (xem mục 3.3) |
| "Gói năm giảm 20% so với gói tháng" | ⚠️ Swagger `CreateSubscriptionPlanDto` **chỉ có `annualPrice`**, không có `monthlyPrice`. Không thể hiển thị so sánh "-20%" nếu BE không thêm field. `[VERIFY]` với Nhật |
| "List flow trước, chờ update VPS rồi mới gán API" | ✅ Đồng ý — Calendar & Face AI làm UI + provider skeleton trước |
| "Noti sổ xuống ngoài màn hình" | ⚠️ Code đã xong, **đang chặn bởi `google-services.json` sai package** — xem `BAO_CAO_BE_PUSH_FCM_2026-07-20.md` |

---

## 5. Vấn đề cần BE xác nhận `[VERIFY]`

| # | Vấn đề | Người trả lời |
|---|---|---|
| 1 | **Schema chính xác của `featureAccess`.** Swagger khai báo `type: object` không có properties. FE đang dùng key phẳng `aiEnabled` / `advancedFinance` / `advancedReports` / `aiChatbot` / `sos` / `unlimitedStorage` / `maxFamilies`. Nhật mô tả key lồng `calendar.enabled` / `calendar.reminders` / `calendar.recurringEvents`. **Xin 1 response JSON thật của `GET /subscription-plans`.** | Nhật |
| 2 | `monthlyPrice` — có bổ sung không? Nếu không thì bỏ ý tưởng hiển thị "giảm 20%" | Nhật |
| 3 | Timeline cho nhóm API role/relationship/deputy (mục 4-#5) | Nhật |
| 4 | Mã lỗi khi bị chặn feature: 403 + `errorCode` cụ thể? FE cần phân biệt "hết quyền do gói" vs "hết quyền do role" để hiện đúng CTA nâng cấp | Nhật |
| 5 | `POST /auth/firebase` dùng để làm gì — social login hay chỉ đăng ký device? | Nhật |
| 6 | Enroll face: Swagger yêu cầu min 3 ảnh, flow Nhật ghi "2-3 ảnh" — chốt số nào | Nhật |
| 7 | Face scan là **tự động khi upload** hay FE phải gọi `POST /face-scan` thủ công? | Nhật |
| 8 | FCM: package name sai + nghi Legacy API (đã báo 20/07, chưa có phản hồi) | Nhật |

---

## 6. Backlog ưu tiên — FE Mobile

### P0 — Tuần này

1. **Merge `giap` → `main`** (resolve 11 commit behind trước)
2. **Calendar module thật** — thay `calendar_screen.dart` mock:
   - `calendar_provider.dart` (ChangeNotifier + `ApiClient.instance`)
   - `models/calendar_event.dart`
   - CRUD + respond + reminder toggle
   - Bắt 403 → dialog "Nâng cấp gói"
3. **Chốt schema `featureAccess`** với Nhật rồi sửa `subscription_screen.dart` + tạo `FeatureAccess` helper dùng chung

### P1 — Tuần sau

4. **Face Profile** trong `member_detail_screen.dart` — enroll (multipart, 3-5 ảnh) + consent dialog + 5 trạng thái (Chưa thiết lập / Đang xử lý / Đã thiết lập / Lỗi / Đã tắt)
5. **Face Suggestion** trong `album_screen.dart` — trạng thái scan, list suggestion, confirm/reject/chọn member khác
6. **Filter album**: Tất cả / Có tôi / Theo thành viên / Chưa tag / Có gợi ý AI
7. Đổi tên `invitation_provider` → `join_request_provider` (dọn nợ kỹ thuật)

### P2 — Chờ BE

8. Role / Relationship / Deputy permission UI — **chặn bởi BE**
9. Wearables API (6 EP) — nối `lib/wear/` với server
10. FCM push — **chặn bởi `google-services.json`**

---

## 7. Nợ kỹ thuật ghi nhận

- `money_provider.dart` + `support_request_provider.dart` chạy song song — chưa chốt flow canonical `[VERIFY nội bộ]`
- `invitation_*` naming lỗi thời sau khi API đổi sang join-request
- `calendar_screen.dart` có `// TODO: gọi API POST /calendar` từ lâu, giờ mới có API
- 4 branch backup local (`giap-backup-*`, `giap-wip-safety-*`) nên dọn sau khi merge main
