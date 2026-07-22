# Thiết lập Firebase + Google Sign-In cho iOS

> Dự án iOS đã được scaffold (`flutter create --platforms=ios`). Code Dart (login/đăng ký bằng Google) đã sẵn sàng.
> Các bước dưới đây **phải làm trên máy Mac có Xcode** + tài khoản Firebase — không làm được trong môi trường Windows/CI hiện tại.

## Thông tin app iOS
- **Bundle ID:** `com.familycare.familyCare` (đăng ký đúng chuỗi này trong Firebase)
- **Deployment target:** iOS 15.0 (đã set trong `project.pbxproj` + `Podfile`)

## Các bước

### 1. Đăng ký app iOS trong Firebase Console
- Vào Firebase project → thêm app **iOS** với bundle ID `com.familycare.familyCare`.
- Tải về `GoogleService-Info.plist`.

### 2. Thêm GoogleService-Info.plist vào project
- Copy `GoogleService-Info.plist` vào thư mục `ios/Runner/`.
- Mở `ios/Runner.xcworkspace` bằng Xcode → kéo file vào target **Runner** (tick "Copy items if needed" + target Runner).
- **KHÔNG commit file này lên git** nếu repo công khai (chứa client ID).

### 3. Cập nhật URL scheme trong Info.plist
- Mở `GoogleService-Info.plist`, copy giá trị `REVERSED_CLIENT_ID`
  (dạng `com.googleusercontent.apps.1234567890-abcdef...`).
- Mở `ios/Runner/Info.plist`, thay chuỗi
  `com.googleusercontent.apps.REPLACE_WITH_REVERSED_CLIENT_ID`
  bằng `REVERSED_CLIENT_ID` thật.

### 4. Bật Google provider + cài pods
- Firebase Console → Authentication → bật **Google** (nếu chưa bật cho Android).
- Trên Mac: `cd ios && pod install` (cần CocoaPods).

### 5. Build
- `flutter build ios` hoặc chạy từ Xcode.

## Ghi chú
- `Firebase.initializeApp()` đã được gọi trong `lib/services/push_service.dart` (đọc `GoogleService-Info.plist` tự động); nếu thiếu plist, app vẫn chạy nhưng Google login/FCM iOS sẽ lỗi (đã bọc try/catch, không crash).
- BE phải cấu hình Google login, nếu không `/auth/firebase` trả **503**.
- `google_sign_in` iOS đọc `CLIENT_ID` từ `GoogleService-Info.plist` tự động — không cần thêm `GIDClientID` vào Info.plist.
