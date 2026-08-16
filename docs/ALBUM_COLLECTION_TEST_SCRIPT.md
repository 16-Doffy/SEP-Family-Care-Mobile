# Kịch bản test Album Collection + analyze-draft

Test cho tính năng vừa wire FE 2026-08-16 (Phase 1 + Phase 2, xem
`AI_HANDOFF_LATEST.md`). Test bằng tài khoản **Manager** hoặc **Deputy**
trước, sau đó lặp lại một vài bước bằng **Member** để kiểm tra không có gì bị
chặn nhầm (tính năng này hiện chưa gate theo `featureAccess`/quyền — mọi vai
trò trong gia đình đều dùng được như nhau).

> Không có nút Sửa/Xóa album ở UI trong đợt này (chỉ Tạo + xem/lọc). Không cần
> test sửa/xóa qua giao diện.

## 0. Chuẩn bị

- Vào tab **Bộ sưu tập** trong màn Album trước — xác nhận card **"+ Tạo
  album"** hiện đầu hàng "Album" (trước "Tất cả ảnh" / "Video").
- Ghi lại số ảnh hiện có ở "Tất cả ảnh" trước khi test (dùng để đối chiếu ở
  bước cuối, đảm bảo ảnh cũ không bị mất/ẩn).

## 1. Tạo album (Collection)

1. Bấm card "+ Tạo album" → nhập tên (vd `Đi biển`) + mô tả tùy chọn → Tạo.
   Kiểm tra: sheet đóng lại, card album mới xuất hiện trong hàng "Album",
   không cần refresh thủ công.
2. Bấm "+ Tạo album" lần nữa, để trống tên, bấm Tạo → kiểm tra: **không** gửi
   request (nút không có phản ứng gì, không văng lỗi màn hình), vì FE chặn
   client-side khi tên rỗng.
3. Tạo thêm 1 album thứ 2 (vd `Sinh nhật`) để có ít nhất 2 album thật cho các
   bước filter phía dưới.

## 2. Upload ảnh có gán album

4. Sang tab **Thư viện**, bấm nút tải lên (FAB) → chọn 1 ảnh từ thư viện máy.
5. Ở sheet "Tải ảnh/video lên": kiểm tra có đủ 3 trường — Mô tả, Quyền xem,
   **Album** (dropdown mới). Mở dropdown Album, xác nhận thấy đúng danh sách
   album vừa tạo + tùy chọn "Không thuộc album nào".
6. Chọn album `Đi biển`, bấm "Tải lên".

## 3. Flow analyze-draft (bước mới trước khi upload thật)

Bước 6 sẽ tự động gọi `analyze-draft` trước khi tải ảnh lên thật. Có 3 nhánh
tùy BE trả gì — không ép được nhánh nào cụ thể từ FE, nên test theo kiểu quan
sát nhánh nào xảy ra và kiểm tra đúng hành vi của nhánh đó:

### Nhánh A — `recommendation = ALLOW` (hoặc BE lỗi/không phân tích được)
- Kiểm tra: ảnh được tải lên **thẳng**, không hiện dialog/sheet nào chen giữa.
- Vào lại tab Bộ sưu tập → bấm card album `Đi biển` → xác nhận ảnh vừa tải
  xuất hiện đúng trong album đó.

### Nhánh B — `recommendation = WARN`
- Kiểm tra sheet cảnh báo hiện ra với: tiêu đề "Ảnh này có thể chưa phù hợp",
  `summary` (nếu BE trả), danh sách `warnings` (mỗi dòng có dấu `•`),
  `detectedLabels` hiện dạng chip (nếu BE trả).
- Test cả 3 nút, mỗi nút test riêng 1 lần (lặp lại bước 4-6 để có sheet WARN
  mới mỗi lần):
  - **"Vẫn tải lên"** → ảnh phải được tải lên thật, xuất hiện đúng trong album
    đã chọn lúc đầu.
  - **"Chọn album khác"** → sheet upload phải mở lại, giữ nguyên mô tả +
    quyền xem đã nhập trước đó, chỉ cần đổi Album rồi bấm Tải lên lại (sẽ gọi
    lại `analyze-draft` một lần nữa với `collectionId` mới).
  - **"Hủy"** → không có ảnh nào được tải lên (kiểm tra số lượng ảnh trong
    album không đổi), không có lỗi màn hình đỏ nào hiện ra.

### Nhánh C — `analysisStatus = UNAVAILABLE` hoặc `SKIPPED`
- Kiểm tra sheet xác nhận đơn giản hiện ra: "Chưa phân tích được ảnh" + nút
  "Vẫn tải lên" / "Hủy".
- Test nút "Vẫn tải lên" → ảnh phải được tải lên thật.
- Test nút "Hủy" (lặp lại bước 4-6 lần nữa) → không có ảnh nào được tải lên.

## 4. Lọc theo album

7. Upload thêm 1 ảnh nữa, lần này chọn album `Sinh nhật` (hoặc "Không thuộc
   album nào").
8. Vào tab Bộ sưu tập → bấm card `Đi biển` → chỉ thấy ảnh đã gán album này,
   **không lẫn** ảnh của `Sinh nhật` hay ảnh không gán album.
9. Bấm card `Sinh nhật` (nếu có ảnh) → kiểm tra tương tự, chỉ thấy đúng ảnh
   của album đó.

## 5. Ảnh cũ không bị ảnh hưởng (quan trọng nhất)

10. Bấm card **"Tất cả ảnh"** → kiểm tra:
    - Tổng số ảnh = số ảnh cũ (ghi ở bước 0) **cộng thêm** số ảnh mới vừa
      upload ở các bước trên.
    - Ảnh cũ (upload trước khi có tính năng này, `collectionId = null`) vẫn
      hiển thị bình thường, không bị ẩn hay báo lỗi gì.

## 6. Kiểm tra không đụng face recognition

11. Mở chi tiết 1 ảnh **đã qua kiểm duyệt SAFE** bất kỳ (kể cả ảnh mới upload
    có gán album) → phần gợi ý khuôn mặt ở dưới vẫn hoạt động như trước (quét
    khuôn mặt, xác nhận/từ chối gợi ý) — không có gì thay đổi hành vi ở khu
    vực này.

---

Ghi lại cho từng bước: **Pass/Fail**, ảnh chụp màn hình nếu Fail, và nguyên
văn response `analyze-draft` nếu bắt được qua log (đặc biệt nhánh B/C, vì
schema response chưa được BE document trong Swagger — cần bằng chứng thật để
đối chiếu nếu có sai lệch field so với mẫu BE gửi).
