# Báo cáo lỗi Backend — Thành viên TỰ rời gia đình (Leave Family)

> **Ngày:** 2026-07-16 · **Người báo:** FE Mobile (Giáp)
> **Mức độ:** 🔴 **Chặn tính năng** — Member/Deputy không có cách nào tự thoát khỏi gia đình
> **Base URL:** `https://api.familycare-digital.com/api/v1`
> ✅ **Đã kiểm chứng 16/07** trên `docs-json` prod (183 paths): **không tồn tại** bất kỳ route tự-rời nào; chỉ có `DELETE /families/{familyId}/members/{userId}` (Manager xoá người khác).

---

# 🔴 Bug — Thiếu API thành viên tự rời gia đình

## 1. Hiện tượng
Màn **Tôi** của Member/Deputy có mục **"Rời gia đình"**, nhưng FE đang phải chặn bằng dialog:
> *"Chưa thể rời gia đình — Ứng dụng đang chờ backend bổ sung API rời gia đình và thông báo cho các thành viên còn lại. Hiện tại chỉ Trưởng nhóm có thể xoá thành viên khỏi gia đình."*

Người dùng muốn thoát khỏi gia đình chỉ có đúng 1 đường: **nhờ Trưởng nhóm xoá mình** — không hợp lý về UX lẫn quyền tự quyết của người dùng.

## 2. Nguyên nhân
Module members hiện chỉ thiết kế **chiều Manager → member** (`DELETE /families/{familyId}/members/{userId}`, soft-delete `status = REMOVED`). **Thiếu chiều ngược lại**: member tự thoát. Đã rà toàn bộ Swagger prod — route "leave" duy nhất là leave **chat conversation**, không phải leave family.

## 3. Yêu cầu BE — contract đề xuất

### 3.1. Endpoint
```
POST /families/{familyId}/members/me/leave
```
*(hoặc `DELETE /families/{familyId}/members/me` — BE chọn, FE theo; ưu tiên POST /leave vì có body lý do.)*

- **Ai gọi được:** thành viên **ACTIVE** của gia đình (mọi role, trừ ràng buộc Manager §3.3). Chỉ cần đăng nhập — **không cần VERIFIED** (giống join-request).
- **Body (optional):**
  ```json
  { "reason": "string, optional, max 500" }
  ```
- **Response:** envelope chuẩn `{ success, message, data }`, 200.

### 3.2. Nghiệp vụ khi rời
1. Đặt membership `status = REMOVED` (**tái dùng đúng logic soft-delete** của DELETE hiện có — đừng viết nhánh mới).
2. Người rời **mất quyền truy cập ngay**: mọi route family-scoped trả 403; `GET /families/my` **không còn trả** gia đình này. ⚠️ Lưu ý bug cũ 2026-06-24: `/families/my` từng không lọc REMOVED — đừng tái phạm ở luồng mới.
3. **Notification cho các thành viên còn lại**: "{tên} đã rời gia đình" (type MEMBER/FAMILY) — dialog FE đang hứa điều này với người dùng.
4. Rời xong có thể **xin vào lại bằng mã mời** (join-request tạo membership mới) — xác nhận hành vi này để FE hiển thị đúng.

### 3.3. Ràng buộc bắt buộc
| Tình huống | Hành vi đề xuất |
|---|---|
| **FAMILY_MANAGER tự rời** khi là Manager duy nhất | **Chặn 409/400** với message rõ: "Chuyển quyền Trưởng nhóm trước khi rời" — gia đình không được "mồ côi" |
| Deputy / Member rời | Cho phép bình thường |
| Người rời là thành viên ACTIVE cuối cùng còn lại | BE chốt: cho rời + gia đình chuyển trạng thái gì? (document rõ) |

> Liên quan: chặn Manager rời kéo theo nhu cầu **API chuyển quyền Trưởng nhóm** (UC17–18, đã nằm trong `API_MOBILE_AUDIT_2026-07-15.md` mục High "role management user-facing"). Nếu ship cùng đợt thì luồng trọn vẹn.

### 3.4. Dữ liệu liên quan của người rời — cần BE chốt & document
| Dữ liệu | Đề xuất FE |
|---|---|
| Assignment đang `ASSIGNED`/`IN_PROGRESS` | Tự huỷ (CANCELED) để Manager giao lại; giữ lịch sử APPROVED cũ |
| Reward settlement chưa `SETTLED` | Giữ nguyên để đối soát (Manager vẫn thấy trong Quản lý thưởng) |
| Ledger/finance đã ghi | Giữ nguyên lịch sử (soft-delete membership, không xoá data) |
| Tin nhắn chat, media album đã đăng | Giữ nguyên (như hành vi REMOVED hiện tại) |

## 4. FE đã sẵn sàng
- Entry "Rời gia đình" + dialog đã có sẵn ở `profile_screen.dart` — BE ship là FE **chỉ thay dialog chặn bằng confirm + gọi API**, sau đó `refreshFamilyContext()` → router tự đưa về màn tạo/tham gia gia đình.
- FE không cần field nào đặc biệt trong response ngoài envelope chuẩn.

## 5. Acceptance test (FE sẽ verify theo đúng kịch bản này)
1. **Member ACTIVE** gọi leave → 200; `GET /families/my` không còn gia đình; gọi route family-scoped bất kỳ → 403.
2. Các máy còn lại nhận **notification "{tên} đã rời gia đình"**; danh sách thành viên không còn người rời (lọc REMOVED).
3. **Manager duy nhất** gọi leave → 409/400 + message hướng dẫn chuyển quyền (không đổi trạng thái gì).
4. Người đã rời **join lại bằng mã mời** → tạo join-request bình thường → Manager duyệt → vào lại được.
5. Assignment đang dở của người rời không còn chặn task list; settlement cũ vẫn hiển thị phía Manager.
