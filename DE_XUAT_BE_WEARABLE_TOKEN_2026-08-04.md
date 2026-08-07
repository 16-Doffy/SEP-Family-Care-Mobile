# Đề xuất BE — Cấp token cho app trên đồng hồ (Wear OS)

Ngày: **2026-08-04** · Người soạn: FE Mobile (nhánh `giap`)
Gửi: team Backend

> **[CẬP NHẬT 07/08/2026 — nhóm đã chốt]** Liên kết đồng hồ ↔ điện thoại **bằng
> token là luồng CHÍNH THỨC**. Việc gõ email/mật khẩu trên đồng hồ **chỉ là
> đường phụ tạm thời** và sẽ bị xóa khỏi app ngay khi 3 endpoint ở mục 2 sẵn
> sàng. Vì vậy mục 2 không còn là "nên có" — nó là **đường đi chính của tính
> năng**, và hiện đang là thứ duy nhất chặn.
>
> FE đã điều chỉnh màn ghép nối trên đồng hồ cho khớp thứ tự ưu tiên này: luồng
> liên kết từ điện thoại là thông điệp chính (kèm trạng thái "máy chủ chưa hỗ
> trợ"), nút "Đăng nhập tạm" bị hạ xuống dạng phụ, viền mờ, nằm dưới cùng.

## 1. Vấn đề

Rule BE đã chốt:

> Wearable không login bằng email/password. Mobile app đang login thay mặt user
> để connect wearable.

FE đồng ý với rule này. Nhưng **app Wear OS là một API client thật**, không phải
thiết bị BLE thụ động: nó gọi trực tiếp `/families/{id}/sos`, `/gps`,
`/tasks/assignments/me`, `/chat/...`, `/notifications`. Mọi endpoint đó đều cần
`Authorization: Bearer <accessToken>`.

Hiện **không có cách nào để app trên đồng hồ lấy được token**:

- 9 endpoint wearable/device trong OpenAPI (bản dump `family-care-api.json`,
  223 path / 290 operation) đều yêu cầu caller **đã** là user đã đăng nhập:
  `GET /wearables/me`, `GET|POST /families/{familyId}/wearables`,
  `PATCH|DELETE /families/{familyId}/wearables/{deviceId}`,
  `GET|POST /families/{familyId}/wearables/{deviceId}/events`.
  `POST|DELETE /devices/tokens` là FCM token, không phải auth.
- `POST /families/{familyId}/wearables` chỉ **tạo bản ghi thiết bị**; response
  (`SosWearableDeviceResponseDto`) không có token nào.

Hệ quả hiện tại trên FE:

1. Màn ghép nối trên đồng hồ (`lib/wear/screens/wear_pairing_screen.dart`) sinh
   mã `FCW-XXXXXX` **cục bộ** và hướng dẫn "nhập mã này trên FamilyCare" — nhưng
   phía mobile (`lib/screens/shared/wearables_screen.dart`) **không có chỗ nhập
   mã**, vì BE không có endpoint nhận mã. Mã này hiện không dùng được.
2. Đường duy nhất chạy được là màn đăng nhập email/mật khẩu **trên đồng hồ**
   (`lib/wear/screens/wear_login_screen.dart`) — **vi phạm chính rule ở trên**.
   FE giữ nó vì bỏ đi là app đồng hồ không gọi được API nào; sẽ xóa ngay khi BE
   có luồng dưới đây.

FE **không mock/workaround** (Rule 2 của repo): không tự sinh token, không dùng
lại token của mobile qua kênh ngoài BE.

## 2. Đề xuất — 3 endpoint (device authorization, kiểu RFC 8628)

### 2.1 `POST /api/v1/wearables/pair-code` — **Bắt buộc**

Đồng hồ gọi, **không cần auth**. Đồng hồ đổi định danh thiết bị lấy mã ghép nối
ngắn hạn.

Request:

```json
{
  "deviceIdentifier": "wearos-emulator-001",
  "deviceType": "SMARTWATCH",
  "deviceName": "Galaxy Watch 6"
}
```

Response `201`:

```json
{
  "pairCode": "FCW-7K3M9Q",
  "pollToken": "opaque-random-string-do-BE-sinh",
  "expiresAt": "2026-08-04T10:05:00.000Z",
  "pollIntervalSeconds": 3
}
```

- `pairCode`: hiển thị trên đồng hồ, **một lần dùng**, sống ngắn (đề xuất 5 phút).
- `pollToken`: bí mật, chỉ đồng hồ giữ, dùng ở 2.3. Phải không đoán được
  (≥ 32 byte random) — đây là thứ đổi ra token thật.
- Cần rate limit theo `deviceIdentifier` để không spam sinh mã.

### 2.2 `POST /api/v1/families/{familyId}/wearables/claim-code` — **Bắt buộc**

**Mobile** gọi (user đã đăng nhập). Đây là bước "mobile login thay mặt user":
user nhập mã đang hiện trên đồng hồ.

Request:

```json
{
  "pairCode": "FCW-7K3M9Q",
  "deviceName": "Đồng hồ của Ba",
  "gpsEnabled": true,
  "sosEnabled": true,
  "ownerMemberId": "uuid-optional"
}
```

Response `201`: **dùng lại nguyên `SosWearableDeviceResponseDto`** của
`POST /families/{familyId}/wearables` để FE không phải parse thêm DTO mới.

Yêu cầu nghiệp vụ: tái dùng đúng logic của endpoint pair hiện tại —
- rule **1 tài khoản = 1 wearable** → trả `409` với mã lỗi hiện có; FE đã hiển thị
  đúng message `Tài khoản này đã kết nối một wearable...`.
- `ownerMemberId` chỉ `FAMILY_MANAGER | DEPUTY_MEMBER` được truyền (giống
  `PairWearableDto`).
- mã sai/hết hạn → `400` hoặc `410` kèm `code` rõ ràng để FE phân biệt được
  "mã sai" và "mã hết hạn".

### 2.3 `POST /api/v1/wearables/pair-code/exchange` — **Bắt buộc**

Đồng hồ poll, **không cần auth** (tự xác thực bằng `pollToken`).

Request:

```json
{ "pollToken": "opaque-random-string-do-BE-sinh" }
```

Response khi mobile **chưa** claim — `202` (hoặc `200` + `status`):

```json
{ "status": "PENDING" }
```

Response khi đã claim — `200`:

```json
{
  "accessToken": "jwt",
  "refreshToken": "jwt",
  "expiresIn": 900,
  "wearableDeviceId": "uuid",
  "familyId": "uuid",
  "user": { "id": "uuid", "fullName": "...", "familyRole": "FAMILY_MEMBER" }
}
```

- Trả token **một lần duy nhất**, sau đó vô hiệu `pollToken`.
- Mã hết hạn mà chưa claim → `410`, đồng hồ tự sinh mã mới.
- Cần rate limit polling (đề xuất tối thiểu 3s/lần, `429` + `Retry-After` nếu
  vượt) — FE `ApiClient` đã đọc `retryAfterSeconds`/`Retry-After` sẵn.
- `refreshToken` phải dùng được với `POST /auth/refresh` hiện tại để đồng hồ tự
  gia hạn (JWT sống 15 phút, người dùng không thể đăng nhập lại trên đồng hồ).

## 3. Nên có (không chặn FE)

1. **Token có scope riêng cho đồng hồ.** Đồng hồ chỉ cần: tạo/xem SOS, gửi vị
   trí, đọc assignment của mình, gửi tin nhắn, đọc thông báo, đọc lịch. Không cần
   tài chính, không cần quản lý thành viên/gói. Token full-quyền trên một thiết bị
   dễ mất là rủi ro không cần thiết.
2. **Ngắt ghép nối phải thu hồi token.** Khi `PATCH .../wearables/{deviceId}`
   với `pairingStatus: UNPAIRED` (hoặc `LOST`), BE nên invalidate luôn access +
   refresh token của đồng hồ đó. Nếu không, "ngắt kết nối" trên mobile chỉ đổi
   trạng thái bản ghi mà đồng hồ vẫn gọi API bình thường.
3. **`GET /wearables/me` trả kèm `hasActiveSession`** để mobile hiển thị đúng
   "đồng hồ đang online" thay vì chỉ dựa vào `lastSeenAt`.
4. **Đổi mã bằng QR.** Nếu 2.1 trả thêm `pairUri` (vd
   `familycare://pair?code=FCW-7K3M9Q`) thì mobile quét QR thay vì gõ 6 ký tự.

## 4. FE sẽ làm gì sau khi BE có

1. Xóa hẳn `lib/wear/screens/wear_login_screen.dart` và nút "Đăng nhập tạm" —
   đúng rule "wearable không login bằng email/password".
2. `wear_pairing_screen.dart`: bỏ sinh mã cục bộ, gọi 2.1, hiện `pairCode` thật,
   poll 2.3 theo `pollIntervalSeconds`, lưu token vào secure storage của đồng hồ.
3. `wearables_screen.dart` (mobile): thêm ô nhập mã ghép nối, gọi 2.2. Giữ nút
   "Kết nối wearable" hiện tại cho `SIMULATED_DEVICE` để test không cần đồng hồ.
4. Cập nhật `API_DOCS.md` theo contract chốt.

## 5. Câu hỏi cần BE trả lời

1. Có đồng ý shape 3 endpoint ở trên không, hay BE muốn hướng khác (vd mobile
   sinh mã rồi user gõ mã **vào đồng hồ**)? Hướng hiện tại chọn "đồng hồ hiện mã,
   mobile gõ mã" vì gõ trên đồng hồ rất tệ.
2. Response của 3 endpoint này có bọc `{ success, data }` như phần còn lại của
   API không? `ApiClient` đang tự unwrap nên cần biết chắc.
3. Token cấp cho đồng hồ có scope riêng (mục 3.1) hay dùng chung token user?
