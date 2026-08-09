# Đề xuất BE — Google login khi email đã tồn tại

Ngày: **2026-08-09** · Phạm vi: Auth / Firebase login

## 1. Bối cảnh

BE đã xác nhận Google login trùng email với tài khoản password cũ sẽ **link/gộp vào tài khoản cũ**, không tạo user mới. Đây là hướng đúng: cùng email là cùng người dùng, không nên chặn họ bằng yêu cầu dùng email khác.

Vấn đề còn lại là FE không biết lần đăng nhập Google vừa rồi là tài khoản mới hay vừa được liên kết vào tài khoản có sẵn. Người dùng cũng không được báo rõ, nên dễ nhầm luồng "Quên mật khẩu" sau này.

## 2. Bắt buộc

### POST /api/v1/auth/firebase

Request giữ nguyên:

```json
{
  "idToken": "firebase-id-token"
}
```

Đề xuất thêm field vào response thành công:

```json
{
  "accessToken": "jwt",
  "refreshToken": "jwt",
  "user": {},
  "linkedExistingAccount": true
}
```

Ý nghĩa:

| Field | Type | Bắt buộc | Mô tả |
|---|---:|---:|---|
| `linkedExistingAccount` | `boolean` | Có | `true` nếu email đã có tài khoản từ trước và BE vừa liên kết Google vào tài khoản đó; `false` nếu đây là tài khoản mới hoặc đã link từ trước. |

FE sẽ dùng cờ này để hiện thông báo một lần sau khi đăng nhập Google thành công:

> Đã liên kết Google với tài khoản sẵn có của bạn. Từ giờ bạn có thể đăng nhập bằng Google.

Không cần đổi status code, không cần endpoint mới, không chặn đăng nhập.

## 3. Nên có

### GET /api/v1/auth/me

Đề xuất BE trả thêm phương thức đăng nhập của tài khoản hiện tại:

```json
{
  "id": "uuid",
  "email": "user@example.com",
  "fullName": "Nguyễn Văn A",
  "authProviders": ["PASSWORD", "GOOGLE"]
}
```

Gợi ý enum:

| Giá trị | Mô tả |
|---|---|
| `PASSWORD` | Tài khoản có thể đăng nhập bằng email/mật khẩu. |
| `GOOGLE` | Tài khoản có thể đăng nhập bằng Google/Firebase. |

FE sẽ hiển thị trong màn Hồ sơ/Bảo mật để người dùng biết tài khoản đang hỗ trợ phương thức nào. Nếu BE chưa trả field này, FE không nên tự suy đoán.

## 4. Không đề xuất

Không làm cảnh báo kiểu "email đã tồn tại, hãy đăng nhập bằng email khác". Cách đó khóa người dùng khỏi chính tài khoản và dữ liệu gia đình của họ, trong khi BE hiện đã xử lý đúng bằng cách liên kết theo email.
