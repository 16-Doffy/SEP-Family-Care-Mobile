# Report 6 — Kịch bản chụp phần Mobile App

Kịch bản này thay các khung Hình 6.4–6.21 trong `Report6_Software User Guides (1).docx`.

## Chuẩn bị

1. Dùng account test **Trưởng nhóm** đang mở trong emulator. Đợi từng màn tải xong trước khi chụp.
2. Chụp bằng biểu tượng **camera** trên thanh công cụ emulator, lưu theo tên gợi ý bên dưới. Không chụp kèm thanh công cụ Android Studio.
3. Không để bàn phím, toast, popup quyền hệ thống hoặc dữ liệu nhạy cảm che nội dung. Nếu có email/số điện thoại/địa chỉ thật, che trước khi đưa vào Word.
4. Với câu tiếng Việt cho AI, **gõ tay trên emulator**. Không dùng `adb shell input text` vì dễ mất dấu.
5. Mỗi lần chụp: dùng ảnh dọc gốc của emulator; trong Word đặt **In Line with Text**, căn giữa, rộng khoảng 14–15 cm.

## Thứ tự chụp đề xuất

### Hình 6.4 — Ứng dụng FamilyCare đang chạy

- Từ Home hoặc Android Studio, mở FamilyCare và đợi vào màn Trang chủ.
- Cần thấy tên app/nội dung Home đã tải và thanh điều hướng dưới cùng.
- Lưu: `06_04_mobile_app_running.png`.

### Hình 6.5 — Không gian gia đình và thành viên

- Trang chủ → **Thành viên**.
- Chụp danh sách thành viên hoặc màn quản lý gia đình có tên vai trò (Trưởng nhóm/Thành viên).
- Không để lộ email/số điện thoại thật.
- Lưu: `06_05_family_members.png`.

### Hình 6.6 — Trang chủ và điều hướng chính

- Quay lại **Trang chủ**.
- Đợi thẻ Quỹ Gia Đình, lối tắt Nhiệm vụ/Thành viên/Ngân sách và thanh điều hướng hiện đủ.
- Đây chính là màn hiện tại phù hợp nhất, không cần tạo thêm dữ liệu.
- Lưu: `06_06_home_navigation.png`.

### Hình 6.8 — Mời hoặc gia nhập gia đình

- Trang chủ → **Mời**, hoặc Thành viên → nút mời thành viên.
- Chụp form mời/chia sẻ lời mời trước khi gửi. Che QR, link invite hoặc thông tin cá nhân nếu có.
- Lưu: `06_08_invite_or_join_family.png`.

### Hình 6.9 — Tạo khoản thu/chi qua AI

- Mở **Trợ lý AI** từ thẻ ở Trang chủ.
- Gõ tay: `Ghi một khoản chi 100.000đ với danh mục Ăn uống`.
- Khi xuất hiện thẻ **Tạo khoản chi** có loại, số tiền, nội dung, ngày và danh mục, dừng trước khi bấm Xác nhận.
- Chụp thẻ đang chờ xác nhận.
- Sau khi chụp, bấm **Hủy đề xuất** để không tạo giao dịch thừa.
- Lưu: `06_09_ai_expense_proposal.png`.

### Hình 6.10 — Mô hình tài chính và gán danh mục vào hũ

- Trang chủ → **Ngân sách** → **Mô hình tài chính**.
- Chụp màn chọn **Quy tắc 80/20** với hai hũ Chi tiêu/Tiết kiệm.
- Bấm **Gán danh mục vào hũ**, cuộn đến khi có ít nhất các dòng Ăn uống, Sinh hoạt, Tiết kiệm / Đầu tư và hũ đã chọn.
- Chụp modal này (có thể dùng ảnh thứ hai ghép dưới cùng Hình 6.10 nếu cần).
- Lưu: `06_10_financial_model.png` và `06_10_jar_category_mapping.png`.

### Hình 6.11 — Đề xuất chia quỹ theo mô hình

- Điều kiện: tháng cần chụp **chưa chia quỹ**, đã có mô hình ACTIVE và có khoản thu đúng tháng.
- AI: `Chia quỹ tháng [tháng chưa chia] theo mô hình tài chính đang áp dụng với tổng tiền [số tiền không vượt quỹ]`.
- Chụp thẻ **Chia quỹ theo mô hình hũ** trước khi xác nhận; phải thấy Tổng tiền, Tháng, Năm, nút Hủy/Xác nhận.
- Nếu AI báo kỳ đã chia hoặc không đủ quỹ: **không dùng ảnh lỗi này cho Hình 6.11**. Dùng tháng khác hoặc trực tiếp tạo thu nhập cho đúng kỳ trước.
- Sau khi chụp, có thể bấm Xác nhận để dùng kết quả cho Hình 6.12.
- Lưu: `06_11_ai_fund_allocation_pending.png`.

### Hình 6.12 — Kết quả/lịch sử chia quỹ và sổ thu chi

- Sau khi xác nhận Hình 6.11 thành công: vào **Ngân sách** → **Mô hình tài chính** → **Lịch sử chia quỹ**, hoặc xem popup Kết quả chia quỹ.
- Chụp thấy kỳ, tổng tiền và phân bổ Spending/Savings.
- Vào **Sổ thu chi gia đình**, chụp phần Ngân sách tháng này có thu nhập, đã chi và phần tỷ lệ hũ.
- Lưu: `06_12_allocation_history.png` và `06_12_monthly_finance_summary.png`.

### Hình 6.13 — Nhiệm vụ và người nhận

- Trang chủ → **Nhiệm vụ**.
- Màn danh sách hiện có task `dọn phòng khách` là dùng được: phải thấy người giao/người làm và badge **30.000 ₫**.
- Hoặc trong AI gõ: `Tạo nhiệm vụ đưa con đi học lúc 7h sáng mai, giao cho [tên thành viên]`, rồi chụp thẻ chờ xác nhận có **Người nhận là tên**, không phải UUID.
- Lưu: `06_13_task_assignment.png`.

### Hình 6.14 — Đề xuất lịch từ AI

- Mở AI. Gõ đầy đủ trong một tin để tránh AI hỏi thêm: `Tạo lịch họp gia đình ngày 20/08/2026 từ 19h đến 20h tại nhà`.
- Chụp thẻ **Tạo sự kiện lịch** trước xác nhận, thấy Tiêu đề, Bắt đầu, Kết thúc và Địa điểm.
- Lưu: `06_14_ai_calendar_pending.png`.

### Hình 6.15 — Sự kiện đã tạo trên lịch

- Xác nhận đề xuất Hình 6.14.
- Mở tab **Lịch**. Chụp ngày 20/08/2026 hoặc danh sách sắp tới có sự kiện vừa tạo.
- Lưu: `06_15_calendar_event_created.png`.

### Hình 6.16 — Tin nhắn gia đình

- Mở tab **Nhắn tin** → chọn hội thoại gia đình.
- Chụp danh sách tin nhắn và ô soạn tin. Dùng hội thoại test; che thông tin riêng nếu có.
- Lưu: `06_16_family_messages.png`.

### Hình 6.17 — SOS ở chế độ xác nhận

- Mở tab **SOS**.
- Chỉ chụp màn hình trước khi gửi hoặc popup xác nhận; **không kích hoạt SOS thật**.
- Che tọa độ/vị trí chính xác nếu xuất hiện.
- Lưu: `06_17_sos_confirmation.png`.

### Hình 6.18 — Bản đồ/vị trí gia đình

- Trang chủ → **Bản đồ**, hoặc mở phần bản đồ theo điều hướng có sẵn.
- Chụp khung bản đồ, trạng thái thành viên/vị trí thử nghiệm. Che tên đường/địa chỉ thực.
- Lưu: `06_18_family_map.png`.

### Hình 6.19 — Album gia đình

- Mở tab **Ảnh**.
- Chụp thư viện ảnh cùng nút upload/thêm ảnh. Dùng ảnh test không nhạy cảm.
- Lưu: `06_19_family_album.png`.

### Hình 6.20 — AI đa lượt có Sửa/Hủy/Xác nhận

- AI: gõ `Tạo lịch đi chơi cuối tuần này`.
- Khi AI hỏi thiếu thông tin, trả lời một tin tiếp theo, ví dụ: `15h đến 17h tại quận 9`.
- Khi thẻ đề xuất xuất hiện, chụp sao cho thấy các nút **Hủy đề xuất**, **Xác nhận tạo lịch** và **Chỉnh lịch hẹn/Sửa**.
- Lưu: `06_20_ai_multiturn_controls.png`.
- Ghi chú test: kiểm tra ngày trả về là 15–16/08 theo kỳ test; nếu thấy ngày 13/08 thì chỉ lưu làm bằng chứng bug BE, không thay cho hình hướng dẫn chính.

### Hình 6.21 — Hồ sơ và cài đặt

- Mở tab **Tôi**.
- Chụp phần danh sách Chỉnh sửa hồ sơ, Tài chính tháng của tôi, Bảo mật, Giao diện, Thanh điều hướng... Không để lộ email/số điện thoại.
- Lưu: `06_21_profile_settings.png`.

### Hình 6.7 — Đăng nhập/đăng ký (chụp cuối cùng)

- Chỉ thực hiện sau tất cả hình trên vì cần đăng xuất.
- Tab **Tôi** → Bảo mật → Đăng xuất (hoặc lối ra đăng nhập tương ứng).
- Chụp màn Đăng nhập/Đăng ký trống, không điền mật khẩu.
- Lưu: `06_07_sign_in_or_register.png`.
- Đăng nhập lại account test sau khi chụp để tránh làm gián đoạn buổi test tiếp theo.

## Chèn vào Word

Đặt mỗi ảnh vào đúng khung `[CHÈN ẢNH HÌNH 6.x]`, giữ nguyên caption `Figure 6.x` bên dưới. Hình 6.10 và 6.12 có thể dùng hai ảnh dọc nối tiếp nếu khung còn đủ chỗ; các hình khác dùng một ảnh dọc.
