# Backlog Backend — Mục "Ảnh" (hướng Google Photos / iOS Photos)

> **Ngày:** 2026-07-22 · **Người đề xuất:** FE Mobile (Giáp) → gửi BE (Nhật)
> **Mức độ:** 🟡 **Không chặn** — FE đã dựng xong UI Library/Bộ sưu tập/Thành viên bằng API hiện có.
> Các mục dưới đây là **điều kiện để đạt trải nghiệm ngang Google Photos thật**; hiện FE đang mô phỏng ở mức "bản xem trước".

---

## Bối cảnh FE đã làm (để BE nắm ngữ cảnh)

- Đổi nhãn giao diện **"Album" → "Ảnh"**. Màn mặc định là **Library** kiểu iOS Photos: lưới tối, gom theo ngày.
- Tab phụ **"Bộ sưu tập"** gồm 3 mục: **Đã ghim** (gắn nhãn *bản xem trước*), **Album** (mới có "Tất cả ảnh"/"Video", **đã ẩn nút Tạo album**), **Thành viên** (nhận diện theo hồ sơ khuôn mặt thành viên đã đăng ký).
- **Toàn bộ là FE-only, không thêm/sửa API nào.** Những giới hạn dưới đây là lý do FE chưa mở khóa các nút đó.

---

## 1. 🔴 Ghim / Yêu thích ảnh (favorite / pin) — cần lưu phía BE

**Hiện trạng:** FE chỉ giữ `Set<String> _pinnedIds` trong RAM → thoát app là mất. Vì vậy "Đã ghim" đang để nhãn *bản xem trước*.

**Đề xuất endpoint:**
```
POST   /families/{familyId}/media/{mediaId}/favorite      body: { "isFavorite": true|false }
GET    /families/{familyId}/media?favorite=true           # lọc danh sách đã ghim
```
- Trả về `isFavorite: boolean` trong DTO media (cả list lẫn detail) để FE render trạng thái.

---

## 2. 🟡 Album collection (album con do người dùng tạo)

**Hiện trạng:** FE đã **ẩn nút "Tạo album"** vì BE chưa có khái niệm album/collection — chỉ có luồng media phẳng theo gia đình.

**Đề xuất tối thiểu:**
```
POST   /families/{familyId}/albums                        body: { "name", "coverMediaId?" }
GET    /families/{familyId}/albums
POST   /families/{familyId}/albums/{albumId}/media        body: { "mediaIds": [...] }
DELETE /families/{familyId}/albums/{albumId}/media/{mediaId}
GET    /families/{familyId}/albums/{albumId}/media
```
- Cần quy tắc quyền: ai được tạo/sửa/xóa album (Manager/Deputy?), member chỉ xem?

---

## 3. 🟡 Tổng số media (media total) — cho header Library

**Hiện trạng:** FE hiển thị **"Đã tải X mục"** (đếm số đã fetch được), **không phải tổng thật**, vì list phân trang không trả tổng.

**Đề xuất:** thêm vào response list phân trang:
```json
{ "items": [...], "total": 1234, "page": 1, "pageSize": 50 }
```
→ FE đổi header thành tổng thật ("1.234 ảnh & video").

---

## 4. 🟠 Signed thumbnail URL ngay trong list

**Hiện trạng:** API **list media không ký URL** → FE phải gọi **GET detail từng ảnh** để lấy URL hiển thị (đã cache + de-dup trong `resolveDisplayUrl`). Với lưới nhiều ảnh, đây là N request phụ, tốn tải và chậm.

**Đề xuất:** list trả sẵn `fileAccess.thumbnailUrl` (đã ký, TTL ngắn) cho mỗi item, giống detail.
→ FE bỏ được toàn bộ vòng resolve, cuộn lưới mượt hơn hẳn.

---

## 5. 🔵 Phân cụm khuôn mặt (face clustering) — dài hạn

**Hiện trạng:** "Thành viên" chỉ gom ảnh theo **hồ sơ thành viên đã đăng ký khuôn mặt** (`taggedMemberId`). Đây **không phải** clustering kiểu Google Photos (tự gom mọi khuôn mặt lạ chưa gán tên).

**Giới hạn API hiện tại (đã kiểm chứng):** face-scan chỉ chạy **từng ảnh một** (`POST .../face-scan {force}`), không có batch; suggestions phải **confirm/reject thủ công**; không có nhóm cụm.

**Đề xuất (nếu có nguồn lực AI):**
- Batch scan cả gia đình (job nền), trả về **các cụm khuôn mặt** kèm ảnh đại diện.
- Cho phép gán 1 cụm → 1 thành viên trong một thao tác.
- Đây là hạng mục lớn; FE ghi nhận là **hướng phát triển**, không kỳ vọng trong sprint hiện tại.

---

## Ưu tiên đề xuất

| Ưu tiên | Mục | Lý do |
|---|---|---|
| 1 | #4 signed thumbnail trong list | Cải thiện hiệu năng tức thì, không đổi UX |
| 2 | #1 favorite/pin | Mở khóa "Đã ghim" thành tính năng thật |
| 3 | #3 media total | Header đúng số, nhỏ gọn |
| 4 | #2 album collection | Mở lại nút "Tạo album" |
| 5 | #5 face clustering | Dài hạn, cần AI |

*FE không bị chặn — sẽ nối ngay khi từng endpoint sẵn sàng.*
