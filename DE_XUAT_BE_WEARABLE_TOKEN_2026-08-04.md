# Wearable Activation — cấp token cho app đồng hồ

Soạn lần đầu: **2026-08-04** · Cập nhật theo API mới: **2026-08-07**

> **Trạng thái: BE đã triển khai trong OpenAPI 2026-08-07.**
> Bản đề xuất cũ từng xin luồng `pair-code` → `claim-code` → `exchange` đã sai giả định.
> Contract mới tách rõ `code` công khai và `sessionId` bí mật, đúng nhu cầu bảo mật.

## 1. Bối cảnh

Mobile và đồng hồ không kết nối trực tiếp qua Bluetooth/Data Layer. Luồng đi qua BE:

1. Đồng hồ xin mã từ BE.
2. Đồng hồ hiển thị mã `FCW-XXXXXX`.
3. Người dùng nhập mã này trên mobile.
4. Mobile pair wearable bằng endpoint hiện có.
5. Đồng hồ claim token bằng `sessionId` bí mật do BE cấp.

Điểm quan trọng: `code` là mã công khai để người dùng gõ tay; `sessionId` chỉ đồng hồ giữ và mới là bằng chứng để claim token.

## 2. Contract BE đã có

### 2.1 Đồng hồ tạo activation

```http
POST /api/v1/wearable-activations
```

Request:

```json
{
  "deviceName": "Wear OS",
  "deviceType": "SMARTWATCH"
}
```

Response:

```json
{
  "sessionId": "uuid",
  "code": "FCW-8SRERK",
  "status": "PENDING",
  "expiresAt": "2026-08-07T12:00:00.000Z",
  "familyId": null,
  "deviceId": null
}
```

### 2.2 Mobile pair bằng mã đang hiển thị

```http
POST /api/v1/families/{familyId}/wearables
```

```json
{
  "deviceName": "Wear OS",
  "deviceType": "SMARTWATCH",
  "deviceIdentifier": "FCW-8SRERK"
}
```

Mobile không cần biết `sessionId`.

### 2.3 Đồng hồ poll trạng thái

```http
GET /api/v1/wearable-activations/{sessionId}
```

Status chính:

- `PENDING`: mobile chưa pair mã.
- `PAIRED`: mobile đã pair, đồng hồ có thể claim token.
- `CLAIMED`: session đã được claim.
- `EXPIRED`: mã hết hạn.

FE chỉ coi `status=EXPIRED` từ BE là hết hạn. Không tự so `expiresAt` với giờ máy vì emulator Wear OS có thể lệch giờ và làm mã vừa tạo đã bị khóa giả.

### 2.4 Đồng hồ claim token

```http
POST /api/v1/wearable-activations/{sessionId}/claim
```

Response:

```json
{
  "activation": {
    "sessionId": "uuid",
    "code": "FCW-8SRERK",
    "status": "CLAIMED",
    "expiresAt": "2026-08-07T12:00:00.000Z",
    "familyId": "uuid",
    "deviceId": "uuid"
  },
  "accessToken": "jwt",
  "refreshToken": "jwt",
  "user": {}
}
```

## 3. FE đã/đang wire

- Mobile: giữ flow nhập mã, gửi `deviceIdentifier = code`.
- Mobile: chỉ kiểm tra mã không rỗng và không quá 100 ký tự trước khi pair; nếu mã không giống dạng `FCW-XXXXXX` hiện tại thì cảnh báo mềm, không khóa nút vì BE chưa cam kết regex chính thức.
- Mobile: phân biệt `WEARABLE_ALREADY_PAIRED` và `DEVICE_IDENTIFIER_TAKEN`.
- Wear OS: không tự sinh mã nữa; gọi `POST /wearable-activations`, hiển thị `code`, poll `sessionId`, claim token khi `PAIRED`. Poll lỗi liên tiếp thì dừng và hiển thị lỗi thay vì chờ âm thầm vô hạn.
- Wear OS: vẫn giữ đăng nhập mật khẩu làm fallback cho môi trường demo nếu activation API chưa sẵn sàng.

## 4. Migration

Thiết bị đã pair bằng mã tự sinh cũ (`familycare-*` hoặc mã FCW local không có activation session) không claim token được bằng flow mới.

Cách xử lý khi test:

1. Vào mobile: **Hồ sơ → Thiết bị đeo**.
2. Xem danh sách thiết bị của gia đình.
3. Xóa hẳn bản ghi cũ nếu cần.
4. Mở lại app đồng hồ để lấy mã activation mới.
5. Nhập mã mới trên mobile và pair lại.
