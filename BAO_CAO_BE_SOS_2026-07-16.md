# Báo cáo lỗi Backend — Chia sẻ vị trí gia đình (Family Map / SOS)

> **Ngày:** 2026-07-16 · **Người báo:** FE Mobile (Giáp)
> **Mức độ:** 🔴 **Chặn tính năng** — Bản đồ gia đình không hiển thị được vị trí thành viên
> **Base URL:** `https://api.familycare-digital.com/api/v1`
>
> ✅ **Đã kiểm chứng 16/07** bằng fetch trọn `docs-json` prod (183 paths / 133 schemas, giống hệt bản Tuần 9): **Bug 1, B, C xác nhận còn nguyên**; riêng mục schema `responses[]` (A cũ) **rút lại** — Swagger đã document, xem Phụ lục.

---

# 🔴 Bug 1 — Thiếu nhóm API chia sẻ vị trí gia đình (404)

## 1. Hiện tượng
Màn **Bản đồ gia đình** hiển thị lỗi đỏ ngay trên UI: **`Cannot GET /api/v1/location/family`**.
FE gọi 3 endpoint dưới đây, **cả 3 đều trả 404** (route chưa tồn tại trên BE).
*(Đã đối chiếu `docs-json` prod fetch 16/07: cả 3 path **không có** trong 183 paths — location chỉ tồn tại trong ngữ cảnh SOS alert.)*

| # | FE đang gọi | Mục đích |
|---|---|---|
| 1 | `GET  /api/v1/location/family` | Lấy vị trí mới nhất của các thành viên đang bật chia sẻ |
| 2 | `POST /api/v1/location/update` | Thiết bị đẩy vị trí hiện tại của **chính mình** lên |
| 3 | `PATCH /api/v1/location/toggle` | Bật/tắt chia sẻ vị trí của **chính mình** |

## 2. Ảnh hưởng cụ thể
- Bản đồ **chỉ hiện được**: marker **của bản thân** (GPS thiết bị) + marker **SOS** (lấy từ alert). → 2 cái này KHÔNG cần API location, nên vẫn chạy.
- Bản đồ **KHÔNG hiện được**: vị trí realtime của các thành viên bình thường (khi không có SOS). Danh sách "Thành viên trên bản đồ" thiếu tọa độ.
- Người dùng nhìn thấy thông báo kỹ thuật. *(FE đã tạm che bằng note "🚧 đang phát triển" để không lộ raw lỗi, nhưng tính năng vẫn trống cho tới khi BE ship.)*

## 3. Phân biệt rõ với cái ĐÃ CÓ (tránh nhầm)
BE **đã có** API vị trí **trong ngữ cảnh 1 SOS alert** và nó **chạy tốt**:
```
POST /families/{familyId}/sos/alerts/{alertId}/locations          (đẩy điểm khi đang SOS)
GET  /families/{familyId}/sos/alerts/{alertId}/location/current    (điểm mới nhất của alert)
```
→ Bug này là về **chia sẻ vị trí gia đình dùng chung** (ngoài SOS) — hiện **hoàn toàn chưa có**. Đây là 2 luồng khác nhau.

---

## 4. Contract đề xuất (chi tiết cho từng endpoint)

Mọi request gắn header `Authorization: Bearer <accessToken>`. Response bọc envelope chuẩn `{ success, message, data }` như các API khác.

### 4.1. `GET /location/family` — danh sách vị trí thành viên
- **Ai gọi được:** thành viên **ACTIVE** của gia đình.
- **Trả về:** vị trí **mới nhất** của mỗi thành viên **đang bật chia sẻ** (`isSharing = true`). Chỉ 1 điểm/người (điểm gần nhất), KHÔNG phải lịch sử.
- **`data`** = mảng các phần tử. FE **parse phòng thủ**, chấp nhận `data` là array trực tiếp **hoặc** bọc trong `{ "shares": [...] }` / `{ "items": [...] }` / `{ "locations": [...] }`.
- **Mỗi phần tử** — tên field FE đọc (kèm fallback FE cũng chấp nhận):

  | Field FE dùng | Kiểu | Fallback FE chấp nhận | Ghi chú |
  |---|---|---|---|
  | `userId` | string | `user.id` | ID định danh thành viên |
  | `displayName` | string | `fullName`, `user.displayName`, `user.fullName` | Tên hiển thị |
  | `latitude` | number | `lat` | |
  | `longitude` | number | `lng` | |
  | `updatedAt` | ISO8601 string | `recordedAt` | Để FE hiện "cập nhật X phút trước" |
  | `isSharing` | boolean | — | (optional) |

- **Ví dụ response mong đợi:**
  ```json
  {
    "success": true,
    "message": "Lấy vị trí gia đình thành công",
    "data": [
      {
        "userId": "0d1c...uuid",
        "displayName": "Nguyễn Văn A",
        "latitude": 10.77689,
        "longitude": 106.70091,
        "updatedAt": "2026-07-16T05:12:38.000Z",
        "isSharing": true
      }
    ]
  }
  ```

### 4.2. `POST /location/update` — đẩy vị trí của chính mình
- **Ai gọi được:** thành viên ACTIVE (tự cập nhật vị trí bản thân).
- **Body:**
  ```json
  { "latitude": 10.77689, "longitude": 106.70091, "accuracy": 18.0 }
  ```
  (`accuracy` = độ chính xác GPS mét, optional.)
- **Nghiệp vụ quan trọng:** BE nên **UPSERT theo user** (mỗi thành viên 1 dòng vị trí hiện tại) — **KHÔNG** insert history tràn bảng, vì FE sẽ đẩy **định kỳ** khi bật share (tham chiếu: trong SOS đang đẩy mỗi **20 giây**).
- **Trả:** 200 (FE không đọc body, sau khi update sẽ tự gọi lại `GET /location/family`).

### 4.3. `PATCH /location/toggle` — bật/tắt chia sẻ
- **Ai gọi được:** thành viên ACTIVE (tự bật/tắt).
- **Body:**
  ```json
  { "isSharing": true }
  ```
- **Nghiệp vụ:** khi `isSharing = false` → thành viên đó **không xuất hiện** trong kết quả `GET /location/family` của người khác (tôn trọng quyền riêng tư).
- **Trả:** 200.

---

## 5. Ràng buộc nghiệp vụ / bảo mật cần chốt
1. **Quyền xem:** chỉ thành viên **ACTIVE cùng gia đình** mới GET được vị trí; người ngoài family → 403.
2. **Quyền riêng tư:** chỉ trả vị trí của người có `isSharing = true`. Mặc định `isSharing` khi chưa từng bật = **false** hay **true**? → cần BE chốt (FE nghiêng về **false** — opt-in).
3. **Điểm mới nhất:** `GET family` trả 1 điểm/người (mới nhất). Nếu BE lưu history, cần lấy bản ghi `updatedAt` lớn nhất.
4. **Không lẫn REMOVED:** loại thành viên đã rời gia đình khỏi kết quả.

---

## 6. Cách FE tiêu thụ & tiêu chí nghiệm thu (acceptance)
- FE đã có sẵn `GpsProvider` parse phòng thủ (bảng field 4.1) + `family_map_screen` render marker theo `userId`/`displayName`/`lat`/`lng`/`updatedAt`. **BE ship đúng path là chạy ngay, gần như không phải sửa FE.**
- **Kịch bản test:**
  1. 2 máy cùng 1 gia đình, cả hai đăng nhập.
  2. Máy A `PATCH /location/toggle {isSharing:true}` → `POST /location/update {lat,lng}`.
  3. Máy B mở Bản đồ → `GET /location/family` → **thấy marker của A** kèm "cập nhật … trước".
  4. Máy A `toggle {isSharing:false}` → Máy B refetch → **A biến mất khỏi bản đồ**.

---

## 7. Về đường dẫn (path) — 1 điểm BE cần quyết
FE hiện gọi **flat**: `/location/family`, `/location/update`, `/location/toggle`.
BE chọn 1 trong 2:
- **(A) Giữ nguyên path flat trên** → FE **không phải đổi gì**.
- **(B) Đổi sang family-scoped** cho nhất quán, ví dụ:
  ```
  GET   /families/{familyId}/members/locations
  POST  /families/{familyId}/locations
  PATCH /families/{familyId}/members/me/location-sharing
  ```
  → Nếu chọn (B), báo path cuối cùng, **FE chỉ đổi 3 dòng path** (logic parse giữ nguyên).

👉 **Ưu tiên FE:** phương án (A) để ship nhanh; nhưng (B) cũng OK, chỉ cần chốt sớm.

---

---

# Phụ lục — các điểm SOS-detail thứ yếu (đã kiểm chứng lại 16/07 trên Swagger prod)

- **A. Schema `responses[]`** — ✅ **RÚT LẠI, không cần BE làm gì**: Swagger **đã document đầy đủ**. `SosAlertResponseDto.responses[] = SosResponseResponseDto { id, sosAlertId, responderMemberId, responseType, message, respondedAt, responderMember }`, trong đó `responderMember = SosMemberSummaryResponseDto { id, displayName, familyRole, user{id, fullName, email, avatarUrl} }`. *(FE đã sửa parse theo field chuẩn `responderMember` — commit 16/07.)*
- **B. Thiếu enum "đang đến"** — ❌ **XÁC NHẬN còn thiếu** (verify enum trong `CreateSosResponseDto`/`SosResponseResponseDto` = `VIEWED | CONFIRM_SAFE | NEED_HELP | RESOLVED | CANCELED`). Nút "Tôi đang đến" vẫn phải gửi `VIEWED` + so text `message`. → Đề xuất thêm `responseType = ON_THE_WAY`.
- **C. Thiếu phone thành viên** — ❌ **XÁC NHẬN còn thiếu** (verify `SosMemberUserResponseDto` chỉ có `id, fullName, email, avatarUrl` — **không có phone**). → Đề xuất bổ sung `phone` vào `SosMemberUserResponseDto` để nút "Gọi" chạy cho người khác.
- **D. (mới ghi nhận)** `status` alert có giá trị thứ 4 **`FALSE_ALARM`** trong enum — FE sẽ bổ sung nhãn hiển thị; BE lưu ý document luồng nào sinh ra status này.
