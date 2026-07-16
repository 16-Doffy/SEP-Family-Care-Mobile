# Mobile API audit — 2026-07-15

Nguồn đối chiếu: Swagger production `GET https://api.familycare-digital.com/api/docs-json`, Flutter trong `lib/`, Use Case Tracker và ERD của đồ án.

> **Cập nhật 2026-07-16:** mục **Location sharing** (Critical) đã được viết thành báo cáo BE chính thức — `BAO_CAO_BE_SOS_2026-07-16.md` (kèm contract 3 endpoint + acceptance test). FE đã che raw lỗi 404 bằng note "🚧 đang phát triển" (cờ `sharingUnavailable`), không còn lộ "Cannot GET /location/family" ra người dùng. Các mục còn lại trong bảng vẫn chờ BE.

## Đã nối trong mobile ở lần audit này

Luồng **mã mời gia đình dùng chung** đã thay thế hoàn toàn invitation email/token cũ:

- `GET /families/{familyId}/invite-code`
- `POST /families/{familyId}/invite-code/regenerate` (chỉ gọi sau dialog xác nhận)
- `GET /invite-codes/{code}`
- `POST /invite-codes/{code}/join-requests`
- `GET /families/{familyId}/join-requests`
- `POST /families/{familyId}/join-requests/{id}/approve`
- `POST /families/{familyId}/join-requests/{id}/reject`
- `GET /me/join-requests`
- `POST /me/join-requests/{id}/cancel`

Các endpoint nhận diện khuôn mặt được cố ý không gọi: toàn bộ `/face-profiles/*`, `face-scan` và `face-suggestions` (kể cả confirm/reject suggestion).

## Cần báo Backend

| Mức độ | Vấn đề đã xác minh | Ảnh hưởng mobile / use case | Cần Backend xử lý |
|---|---|---|---|
| Critical | Không có API location sharing thường. Code cũ gọi `/location/family`, `/location/toggle`, `/location/update`; các path này không có trong Swagger. Chỉ có location trong SOS alert. | UC79–UC81, Family Map sẽ 404 nếu dùng `GpsProvider`. | Thiết kế API family location opt-in, ghi điểm vị trí, latest/history; tách rõ khỏi SOS route. Hoặc xác nhận bỏ UC79–81 khỏi scope demo. |
| High | Không có `PATCH /auth/me`. | Màn Edit Profile chỉ có thể hiển thị read-only, không lưu tên/điện thoại/avatar. | Thêm endpoint user tự cập nhật profile, whitelist field và trả user sau cập nhật. |
| High | Không có user-facing API cập nhật role/relationship/member status. Endpoint admin không dùng được cho app. | UC17–UC18 bị block: Manager không thể grant/revoke Deputy hoặc sửa quan hệ. | Thêm `PATCH /families/{familyId}/members/{userId}` (Manager-only), validate chỉ một Manager. |
| High | Không có API Calendar. | UC70–UC72/màn Calendar chưa có dữ liệu thật. | CRUD `/families/{familyId}/events`, query theo khoảng thời gian, attendee/reminder và schema response. |
| High | Không có API AI Assistant. | Màn AI chỉ là UI/demo, không thể chat hay lấy thống kê thật. | `POST /families/{familyId}/ai/chat`, streaming/async contract, kiểm soát quyền theo member và quota plan. |
| Medium | Không có đăng ký FCM token. | Notification hiện chỉ pull REST; không có push/SOS notification khi app background. | `POST`/`DELETE /auth/fcm-tokens`, token/device/platform, refresh/unregister contract. |
| Medium | `GET /finance/ledger/entries` thiếu filter `memberId`. | Manager không lọc được ledger theo thành viên cho UC21/finance review. | Thêm `memberId` (và phân quyền dữ liệu private) vào query contract. |
| Medium | Join request chưa có realtime; guide BE xác nhận notifications vẫn là stub. | Người xin vào không biết ngay khi Manager duyệt/từ chối nếu không mở app. | Ship notification/push hoặc WebSocket; hiện mobile poll mỗi 12 giây khi màn “Yêu cầu của tôi” mở. |
| Medium | Contract subscription không nhất quán: runtime plan trả `FREE/MONTHLY/YEARLY`, trong schema quản trị cũ còn `FREE/PLUS/PREMIUM`. | Fallback/copy UI có thể sai tên plan và giá. | Chuẩn hóa enum, billing cycle và ý nghĩa `annualPrice`; version Swagger theo một contract duy nhất. |
| Low | Album guide có soft delete/restore/permanent delete nhưng không document query để liệt kê media đã xóa. | Mobile không thể làm “Thùng rác” đúng contract, nên UI chỉ giữ xóa mềm; restore/permanent chỉ khả dụng nếu BE trả item deleted từ một endpoint khác. | Xác nhận `GET /albums/media` có `deletedView`/`includeDeleted` hay bổ sung endpoint/query chính thức. |

## Ghi chú kiểm thử

- `GpsProvider` vẫn tồn tại để không phá UI hiện tại. **Đã cập nhật 2026-07-16**: bắt 404 `/location/*` → cờ `sharingUnavailable`, Family Map hiện note "🚧 Chia sẻ vị trí gia đình đang được phát triển" thay vì raw lỗi. Parse phòng thủ sẵn (nhận `shares`/`items`/`locations`, `lat`/`lng`, `recordedAt`) → BE ship đúng path là chạy ngay.
- Mã mời luôn 8 ký tự; mobile gửi/lưu dạng uppercase, còn BE tự trim và không phân biệt hoa/thường.
- Album đã theo manual tagging: Manager `MARK_SAFE` trước, chỉ media `SAFE` hiện nút tag, gỡ tag chỉ khi `permissions.canRemove`; không gọi bất kỳ route Face AI nào.
