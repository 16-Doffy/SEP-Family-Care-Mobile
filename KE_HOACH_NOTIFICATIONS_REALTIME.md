# Notifications Realtime — Trạng thái triển khai FE Mobile

> **Ngày:** 2026-07-16 · **Nguồn:** Hợp đồng WS `/notifications` (BE Nghĩa) + kế hoạch FE.
> **Kết quả:** ✅ **Phase 1 (realtime foreground) — ĐÃ CODE**. Phase 2 (FCM background) — pending Leader.

---

## ✅ Đã làm (Phase 1)

| Hạng mục | File | Ghi chú |
|---|---|---|
| Dependency | `pubspec.yaml` | **`socket_io_client 3.1.6`** — hỗ trợ Socket.IO **v3/v4** (khớp NestJS gateway) → resolve `[VERIFY protocol version]` |
| Transport Socket.IO | `lib/services/notification_socket_service.dart` (mới) | Connect `<origin>/notifications` + `auth:{token}`; 3 event `notification:new|unread-count|error`; **tự quản reconnect** (tắt built-in) + backoff, mỗi lần đọc **token mới nhất** từ ApiClient |
| Origin cho socket | `lib/services/api_client.dart` | `ApiClient.origin` (bỏ `/api/v1`) → resolve `[VERIFY host]` = `https://api.familycare-digital.com` |
| State realtime | `lib/providers/notification_provider.dart` | `startRealtime/stopRealtime`; `notification:new` **id nullable** (persisted→list+badge, push-only→chỉ toast); `unread-count` **theo từng family** (map `familyId→count`); `fetchUnreadCount()` REST |
| Điều hướng | `lib/navigation/notification_router.dart` (mới) | Map `referenceType`+`referenceId` → route **thật** (role-aware); lạ/null → về list, không crash → resolve `[VERIFY route]` |
| Lifecycle + toast | `lib/navigation/family_shell.dart` | `startRealtime` khi vào shell (đã đăng nhập), `stopRealtime` khi dispose; toast in-app cho mọi `notification:new` + nút "Xem" điều hướng |
| Tap noti | `lib/screens/shared/notifications_screen.dart` | Dùng `NotificationRouter` (bỏ mapping cũ theo `type`) |

**Nguyên tắc an toàn:** REST poll 15s ở `family_shell` **giữ nguyên làm fallback** (socket rớt vẫn nhận noti + SOS). Socket cô lập — lỗi socket không phá luồng cũ.

### Bảng điều hướng `referenceType` → route (đã map)
| `referenceType` | Route |
|---|---|
| `SOS_ALERT` | `/{role}/sos` |
| `ALBUM_MEDIA` | `/album` |
| `JOIN_REQUEST` | `/manager/invite-requests` (mgr/deputy) |
| `FAMILY` | `/{role}/home` |
| `FAMILY_MEMBER` | `/manager/member/:id` (mgr) |
| `TASK_ASSIGNMENT` | `/{mgr:manager\|member}/tasks` |
| `CALENDAR_EVENT` | `/manager/calendar` |
| `BUDGET_ALERT` | `/manager/finance-alerts` |
| `FINANCIAL_GOAL` | `/manager/goal-detail?goalId=:id` |
| `CONVERSATION` | `/{role}/chat` |
| `GENERAL`/lạ/null | — (ở lại list) |

---

## ⏳ Pending — cần Leader/BE chốt trước khi làm

### Phase 2 — FCM background (chưa code, cần native config)
- `firebase_core` + `firebase_messaging` + `google-services.json` (Android) / APNs (iOS) — **chạm native config**, cần Leader (Nhật) đưa vào scope.
- `POST /devices/tokens` (đăng ký) / `DELETE /devices/tokens/:token` (logout) — REST đã có sẵn ở BE.
- Deep-link FCM dùng chung `NotificationRouter` (đã sẵn).

### `[VERIFY]` còn lại
1. **Chiến lược khi app vào background**: hiện giữ socket đến khi dispose shell; khi có FCM thì nên ngắt socket ở background & dựa FCM. Cần chốt cùng Phase 2.
2. **Chat transport**: CHAT là push-only (id null) trên `/notifications`; module `chats` có unread/list riêng. Xác nhận FE wire CHAT qua đâu để không double-source.
3. **Privacy lock-screen CHAT**: FCM đẩy nguyên `body` = nội dung tin nhắn → cần chốt che/generic ở lock-screen (chính sách sản phẩm).
4. **iOS**: repo hiện chưa có thư mục `ios/` — FCM iOS cần tạo project + APNs sau.

---

## Test / nghiệm thu (cần chạy trên device — chưa verify runtime)
- [ ] Kết nối → nhận `notification:new` không cần join thủ công.
- [ ] Token 15' hết hạn → tự reconnect với token mới (backoff), không mất event.
- [ ] `id != null` → vào list + badge; `id == null` → chỉ toast.
- [ ] `unread-count` cập nhật badge đúng theo `familyId`; mark-read máy A → máy B badge giảm.
- [ ] Bấm mỗi loại noti điều hướng đúng; `referenceType` lạ → về list, không crash.
- [ ] Script BE: `node server/scripts/notifications-ws-test.mjs <email> <password>`.
