# Báo cáo BE — Thông báo không đến được khi app ở nền / đã tắt (cần FCM)

> **Ngày:** 2026-07-20 · **Người báo:** FE Mobile (Giáp) · **Mức độ:** 🔴 Chặn tính năng cảnh báo SOS
> **Tóm tắt 1 dòng:** FE đã làm hết phần client làm được; thông báo vẫn không tới khi app ở nền vì **chưa có push FCM**. Cần BE xác nhận 4 điểm ở §3.

---

## 1. Tình trạng hiện tại

### Đang chạy được
| Kênh | Trạng thái |
|---|---|
| REST notifications (list / unread-count / read / read-all) | ✅ Đã nối |
| Socket.IO `/notifications` realtime | ✅ Đã nối, `notification:new` + `unread-count` chạy đúng |
| Poll REST 15s (foreground) / 30s (nền) — fallback khi socket rớt | ✅ Đã nối |
| Thông báo hệ thống (khay + chuông + heads-up) | ✅ FE đã làm bằng `flutter_local_notifications`, tạo sẵn 2 channel: **`sos_alerts`** và **`general_notifications`** |
| Deep-link khi bấm thông báo | ✅ Có `NotificationRouter`, map `referenceType`/`referenceId` → màn |
| `POST /devices/tokens` | ❌ **FE chưa gọi** (chưa có Firebase, xem §2) |

### KHÔNG chạy được
| Trạng thái máy nhận | Kết quả |
|---|---|
| App đang mở | ✅ Có banner + toast + thông báo hệ thống |
| **App ở nền** (nhấn Home) | ❌ **Không nhận được** |
| **App đã tắt hẳn** | ❌ **Không nhận được** |

---

## 2. Nguyên nhân (đã xác minh bằng log, không phải phỏng đoán)

Log máy nhận, ngay thời điểm app xuống nền:

```
visibilityChanged oldVisibility=true newVisibility=false      ← app xuống nền
NotifSocket: disconnected
NotifSocket: connect_error SocketException:
    Failed host lookup: 'api.familycare-digital.com'
    (OS Error: No address associated with hostname, errno = 7)
SosProvider: fetchAlerts failed: Không thể kết nối đến server
```

**Diễn giải:** app xuống nền → **mất phân giải DNS / mất mạng** → socket đứt, REST poll fail → không lấy được cảnh báo → không có gì để hiển thị. Mở app lại → `NotifSocket: connected` → lúc đó thông báo mới bung ra.

**Vì sao FE không tự giải được:** mọi cơ chế client (socket, poll, local notification) đều **phụ thuộc tiến trình app còn sống + còn mạng nền**. Android (Doze / App Standby / Data Saver) siết cả hai, và app bị tắt hẳn thì không còn tiến trình nào chạy. Đây là giới hạn nền tảng, không phải bug code.

→ **Chỉ FCM giải quyết được**: Google Play Services giữ kết nối ở tầng hệ điều hành, nhận push và **đánh thức app hộ** — không cần app sống, không cần app có mạng nền.

---

## 3. Cần BE xác nhận / cung cấp (4 điểm)

### 3.1. 🔴 FCM đã thực sự bật trên prod chưa?
Trong file env mẫu team gửi, biến này **để trống**:
```
FCM_SERVER_KEY=
```
→ Nhờ xác nhận: BE **đã gửi push FCM thật** khi có notification chưa, hay mới chỉ có endpoint lưu token? Nếu chưa gửi thì FE có tích hợp cũng không nhận được gì.

### 3.2. 🔴 Cần `google-services.json` từ ĐÚNG Firebase project BE đang dùng
FE bắt buộc dùng **cùng một Firebase project** với BE thì token mới hợp lệ.
Nhờ gửi: **`google-services.json`** cho Android, package name **`com.familycare.family_care`**
(hoặc gửi Firebase **project ID** + cấp quyền để FE tự tải).

### 3.3. 🟡 Chốt shape payload FCM
FE cần payload để điều hướng đúng màn khi user bấm thông báo. Đề nghị dùng **data message** (hoặc notification + data) với các key:

| Key | Kiểu | Dùng để |
|---|---|---|
| `title` | string | Tiêu đề hiển thị |
| `body` | string | Nội dung |
| `type` | string | `SOS`/`TASK`/`FINANCE`/`CHAT`… — chọn icon/nhóm |
| `referenceType` | string | Điều hướng — xem danh sách dưới |
| `referenceId` | string | id đối tượng đích |
| `familyId` | string | Xác định family liên quan |

`referenceType` FE **đã hỗ trợ sẵn**: `SOS_ALERT`, `ALBUM_MEDIA`, `JOIN_REQUEST`, `FAMILY`, `FAMILY_MEMBER`, `TASK_ASSIGNMENT`, `CALENDAR_EVENT`, `BUDGET_ALERT`, `FINANCIAL_GOAL`, `CONVERSATION`.
Giá trị lạ/thiếu → FE fallback về màn danh sách thông báo, **không crash**.

### 3.4. 🟡 Riêng SOS phải là push ưu tiên cao
Để cảnh báo SOS xuyên được Doze (máy đang ngủ), khi gửi SOS nhờ set:
- `android.priority = "high"`
- `android.notification.channel_id = "sos_alerts"` ← FE đã tạo sẵn channel này (Importance.max)

Các loại còn lại dùng `channel_id = "general_notifications"`.

---

## 4. Phần FE sẽ làm ngay khi có §3.2
1. Thêm `firebase_core` + `firebase_messaging`, gắn `google-services.json`.
2. Gọi `POST /devices/tokens` sau đăng nhập / khi được cấp quyền; `DELETE /devices/tokens/{token}` khi logout.
3. Xử lý push ở cả 3 trạng thái (foreground / background / terminated), deep-link dùng lại `NotificationRouter` đã có.

Ước tính: **xong trong ngày** kể từ khi nhận được file config.

---

## 5. Tiêu chí nghiệm thu
1. Máy B **tắt hẳn app** → máy A phát SOS → máy B **hiện thông báo + chuông** ở màn hình khoá.
2. Bấm thông báo → mở đúng màn SOS của cảnh báo đó.
3. Máy B đăng xuất → không còn nhận push của tài khoản cũ (token đã `DELETE`).
4. Notification thường (task/finance/join-request) về đúng channel `general_notifications`.

---

## 6. Ghi chú
- Việc này **không đụng** tới các API đã có; chỉ cần bật/ xác nhận kênh gửi FCM và cấp file config.
- Trong lúc chờ, FE giữ nguyên giải pháp tạm (socket + poll + local notification) — hoạt động **khi app đang mở**, và đây là mức tối đa client làm được.
