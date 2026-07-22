# Kế hoạch cải thiện FE theo BE update — 2026-07-22

> Nguồn: OpenAPI `Family Care API v1.0` (BE vừa cập nhật) + ghi chú VQuan (AI Chatbot) + danh sách Finance của BE.
> Người phân tích: FE Mobile (Giáp). Trạng thái: **kế hoạch (preview), chưa sửa code**.

---

## 0. Đối chiếu nhanh spec ↔ FE

| Vùng | FE hiện tại | Kết luận |
|---|---|---|
| AI Chatbot | `ai_assistant_screen.dart` mock cục bộ (keyword → câu trả lời từ Provider) | 🔴 Thay bằng tích hợp thật |
| Finance analytics (`/summary`, `/cash-flow-summary`, `/category-spending-summary`, `/member-contribution-summary`) | Chỉ `/finance/overview` | 🟠 Bổ sung |
| Ledger `/entries/:id` GET/PATCH/DELETE | Chỉ list + create | 🟠 Bổ sung sửa/xóa |
| Face enrollment `/face-profiles/{memberId}/enroll` | Không có | 🟠 Bổ sung (unblock Ảnh→Thành viên) |
| Google login `/auth/firebase` | Không có | 🔵 Tùy chọn |
| FCM `/devices/tokens` | ✅ `push_service.dart` | Xong |
| SOS contacts + batch location | ✅ `sos_provider` | Xong |
| Locations map | ✅ đã nối | Xong |

## ⚠️ Cần BE xác nhận trước (đồng bộ tài liệu)
Các endpoint sau **BE liệt kê nhưng KHÔNG có trong OpenAPI vừa gửi** — xác nhận đã deploy trước khi code:
- `GET /finance/summary`, `/finance/cash-flow-summary`, `/finance/category-spending-summary`, `/finance/member-contribution-summary`
- `GET/PATCH/DELETE /finance/ledger/entries/{entryId}`
- `DELETE /finance/categories/{categoryId}`

---

## P1 — 🔴 AI Chatbot thật (thay mock) — ưu tiên cao nhất

**Vì sao:** BE đã có đủ luồng, đây là tính năng "wow" cho đồ án; mock hiện tại không dùng dữ liệu thật và không tạo được giao dịch/task.

**Endpoint:** base `/families/{familyId}/ai-chatbot`
- `POST /conversations {title?}` → `{id, conversationTitle, createdAt}`
- `GET /conversations?page&limit` → `{items:[{id, conversationTitle, lastMessage, createdAt}], meta}`
- `GET /conversations/{id}/messages?page&limit` → mỗi msg `{id, senderType, content, relatedModule, createdAt, pendingAction}`
- `POST /conversations/{id}/messages {content}` → `{userMessage, aiMessage, pendingAction|null}` (3–15s, không streaming)
- `POST .../messages/{messageId}/confirm-action` → `{actionType, result:{id}}`
- `POST .../messages/{messageId}/reject-action`
- `DELETE /conversations/{id}`

**Việc FE:**
1. `models/ai_conversation.dart`, `models/ai_message.dart` (kèm `PendingAction {messageId, actionType, status, preview, expiresAt}`), parse envelope `{success,message,data}`.
2. `providers/ai_chatbot_provider.dart`: list/create conversation, load messages (paginate), send (hiện indicator "đang trả lời"), confirm/reject action.
3. Viết lại `ai_assistant_screen.dart`: danh sách hội thoại + màn chat; bong bóng user/AI; **thẻ xác nhận** khi `pendingAction.status == 'PENDING'` (nút Xác nhận/Hủy), tự vô hiệu sau `expiresAt` (15').
4. Xử lý mã lỗi: 409 (đã xử lý → double-tap), 410 (hết hạn → disable nút), 403 (thiếu quyền), 502 (AI im lặng → cho retry, tin user đã lưu), 503 (chưa cấu hình → báo "AI chưa bật").
5. Gate `ai.assistant`/`ai.chatbot` theo featureAccess (fail-open, để BE 403 quyết).

**Rủi ro:** TB (state pendingAction + expiry). **Effort:** L. **BE:** không cần thêm.

---

## P2 — 🟠 Finance analytics + Ledger CRUD

**Vì sao:** BE vừa nâng cấp Finance; đây là nơi FE hưởng lợi nhiều nhất.

**Việc FE:**
1. `FinanceProvider`/`WalletProvider`: thêm gọi `/summary`, `/cash-flow-summary`, `/category-spending-summary`, `/member-contribution-summary` (sau khi BE xác nhận).
2. Màn hình tổng quan Finance mới hoặc nâng cấp `wallet_screen`: biểu đồ dòng tiền vào–ra, chi theo danh mục (đã có `waffle_chart`/`ring_chart` tái dùng), đóng góp theo thành viên.
3. Ledger: thêm **GET chi tiết / PATCH sửa / DELETE (void)** giao dịch → mở nút Sửa/Xóa trong danh sách giao dịch.
4. Danh mục: thêm `DELETE /categories/:id` (ngưng dùng).

**Rủi ro:** Thấp-TB (parse phòng thủ vì schema summary chưa có trong OpenAPI). **Effort:** M-L. **BE:** xác nhận 4 endpoint + ledger :id.

---

## P3 — 🟠 Face enrollment (unblock Ảnh → Thành viên)

**Vì sao:** Màn "Thành viên" + face-suggestions chỉ chạy khi thành viên **đã enroll khuôn mặt**. Hiện FE chưa có UI enroll → tính năng nhận diện trống.

**Endpoint:**
- `POST /face-profiles/{memberId}/enroll` (multipart: `files` 3–5 ảnh, `consentConfirmed:true`)
- `GET /face-profiles/{memberId}` (trạng thái)
- `PATCH .../disable` · `PATCH .../enable` · `DELETE` (`{confirmation:"DELETE_FACE_PROFILE"}`)

**Việc FE:**
1. `providers/face_profile_provider.dart`.
2. Màn "Hồ sơ khuôn mặt" (trong Ảnh→Thành viên hoặc Cài đặt thành viên): chụp/chọn 3–5 ảnh, **màn hình đồng ý (consent) rõ ràng** trước khi gửi (dữ liệu sinh trắc — nhạy cảm), trạng thái enrolled/disabled, nút tắt/xóa.
3. Nối vào cover "Thành viên" hiện có: nếu member chưa enroll → hiện CTA "Đăng ký khuôn mặt".

**Rủi ro:** TB (multipart nhiều file + quyền riêng tư). **Effort:** M. **BE:** không cần thêm. **Lưu ý pháp lý/UX:** phải có consent tường minh, không auto-upload.

---

## P4 — 🔵 Tùy chọn (làm sau nếu còn thời gian)

| Việc | Endpoint | Ghi chú |
|---|---|---|
| Đăng nhập Google | `POST /auth/firebase {idToken}` | Cần thêm `firebase_auth`+`google_sign_in`, cấu hình Firebase; 503 nếu BE chưa bật |
| Đổi giá gói theo billingPeriod | `subscription-plans` có `monthlyPrice/yearlyPrice/billingPeriod` | `subscription_screen` đang hiển thị theo `annualPrice`; cập nhật để khớp field mới |
| Recurring task nâng cao | `/tasks/recurring`, `/schedule`, `/generate-assignments` | Kiểm tra `task_management` đã dùng đủ chưa |

---

## Thứ tự đề xuất
**P1 (AI thật) → P2 (Finance) → P3 (Face enroll) → P4.**
Làm từng cụm có kiểm chứng (`flutter analyze` + `flutter test` sau mỗi cụm), không push tới khi được yêu cầu.

## Việc kèm theo (quy tắc dự án)
- Cập nhật `API_DOCS.md` sau khi BE xác nhận nhóm endpoint Finance còn thiếu trong OpenAPI.
- Mỗi thay đổi FE lớn: preview trước khi sửa.
