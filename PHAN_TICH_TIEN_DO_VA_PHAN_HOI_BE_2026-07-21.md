# Phân tích tiến độ FE Mobile + Phản hồi yêu cầu BE — 21/07/2026

**Người thực hiện:** Giáp (SE171532) — FE Mobile (Flutter)
**Nguồn đối chiếu:** repo `SEP-Family-Care-Mobile` (branch `giap`, dirty) × `Family_Care_DOC/Tuần 10/docs-json.json`
**Tiếp nối:** `PHAN_TICH_TIEN_DO_TUAN10_2026-07-20.md` — tài liệu này chỉ ghi **delta + phản hồi feedback của Nhật**, không lặp lại nội dung cũ.

---

## 1. Delta so với báo cáo 20/07

| Hạng mục | 20/07 | 21/07 |
|---|---|---|
| Calendar | ❌ Mock 100% | ✅ **Đã nối 7/7 endpoint thật** (`91b0146`) + gating gói + fail-open khi `featureAccess` rỗng (`123b639`) + mở cho Deputy/Member (`dc320a6`) |
| Thanh điều hướng tùy chỉnh | — | ✅ Mới (`b5da639`) — user chọn 3/6 mục, `tab_config_provider.dart` |
| Widget test Member/Deputy | — | ✅ Mới (`5dccc35`) |
| Icon trợ lý AI | — | ✅ Mới — `lib/widgets/ai_chatbot_icon.dart` (CustomPainter, 184 dòng, có `Semantics`, dùng `AppColors`) |
| Face AI | ❌ 0 dòng | ❌ **Vẫn 0 dòng** |
| Wearables API | ❌ Chưa nối | ❌ Vẫn chưa |

**Con số hiện tại:** Swagger 260 operations / 201 paths → **213 op thuộc scope mobile** (47 op là Admin — của Duy).

**Uncommitted:** 5 file modified + `lib/widgets/ai_chatbot_icon.dart` untracked. → **commit trước khi merge `giap` → `main`.**

---

## 2. Kiểm tra `lib/screens/shared/ai_assistant_screen.dart`

**Kết luận: màn hình này là mock 100%, và KHÔNG có endpoint nào trên Swagger để nối vào.**

### 2.1 Icon — ✅ Đã xong đúng chuẩn

| Kiểm tra | Kết quả |
|---|---|
| Đã thay icon cũ | ✅ `AiChatbotIcon` dùng ở AppBar (size 30) + avatar bubble bot (size 28) |
| Dùng `AppColors` token, không hardcode hex | ✅ |
| Có `Semantics` + `RepaintBoundary` | ✅ |
| Route `/ai` | ✅ Đã đăng ký, gọi từ `home_dashboard_screen.dart:515` và `child_home_screen.dart:327` |

⚠️ Còn 2 chỗ hardcode hex trong chính `ai_assistant_screen.dart`: `Color(0xFFF3F4F6)` (dòng 51, 106, 112) → nên đổi sang token `AppColors` cho nhất quán.

### 2.2 Logic — ❌ Toàn bộ là hardcode

```dart
String _autoReply(String q) {
  if (q.toLowerCase().contains('chi'))
    return 'Tháng này bạn đã chi 35,000,000 ₫ ...';   // ← số bịa
  if (q.contains('task')) return 'Hiện có 3/5 tasks ...'; // ← số bịa
  ...
}
```

Rủi ro: **màn này đang hiển thị số liệu tài chính giả cho user.** Nếu demo Review 3 mà supervisor gõ "chi tiêu tháng này", app sẽ trả `35,000,000 ₫` không liên quan tới ví thật → mất điểm nặng.

### 2.3 Không có API — blocker thật sự

Quét toàn bộ 201 path: **không có tag/endpoint nào cho AI assistant / chatbot.** Không có `/ai`, `/assistant`, `/chatbot`, `/conversations/ai`.

→ Nhật yêu cầu "sửa icon trợ lý AI" (mục 1.2) nhưng **chưa cấp API cho chính trợ lý đó.** Đây là câu hỏi `[VERIFY]` số 1.

### 2.4 Đề xuất xử lý (chọn 1)

| Phương án | Mô tả | Chi phí |
|---|---|---|
| **A — Rule-based thật (khuyến nghị)** | Bỏ `_autoReply` hardcode; đọc số thật từ `FinanceProvider` / `TaskProvider` / `CalendarProvider` đã có sẵn. 4 quick-suggestion hiện tại map đúng 4 provider. Không cần BE. | ~3h |
| B — Chờ BE | Giữ mock, thêm badge "Beta — dữ liệu mô phỏng" | 15 phút |
| C — Ẩn khỏi Review 3 | Gỡ entry point ở 2 màn home | 10 phút |

→ **Đề xuất A.** Dữ liệu đã nằm sẵn trong provider, chỉ cần format. Nếu không kịp thì tối thiểu làm B — **không được để số bịa không có nhãn.**

---

## 3. Phản hồi từng mục feedback của Nhật

### 3.1 "Cải thiện giao diện đẹp hơn 1 tí" (mục 1.1)

Quá chung chung, không actionable. **Cần Nhật chỉ rõ màn nào.** Đề xuất Nhật comment trực tiếp lên ảnh chụp màn hình thay vì mô tả chữ.

Từ phía FE, 3 điểm nợ kỹ thuật đã biết:
- Hardcode hex rải rác (`0xFFF3F4F6`, `0xFF...`) thay vì `AppColors` — vi phạm quy ước design system
- `ai_assistant_screen.dart` viết 1 dòng dài (`Row(children: [...])` inline) → khó bảo trì
- Chưa có empty state / skeleton loading nhất quán giữa các màn

### 3.2 "Sửa icon trợ lý AI" (mục 1.2) — ✅ **Đã xong**, chờ Nhật duyệt

### 3.3 Chat: đổi tên, xem lịch sử, xem ảnh/link đã gửi (mục 1.3)

**Tin tốt: API đủ, provider đã có sẵn 90%. Chỉ thiếu UI.**

| Yêu cầu | Endpoint | Provider | UI | Việc cần làm |
|---|---|---|---|---|
| Đổi tên chat | `PATCH .../conversations/{id}` | ✅ `updateConversation({name})` — dòng 286 | ✅ `_showRenameDialog()` — `chat_screen.dart:576` | **Đã xong** |
| Xem lại lịch sử nhắn | `GET .../messages` (DESC + cursor) | ✅ `fetchMessages()` — dòng 341 | ⚠️ | Provider chưa expose **load-more theo cursor**. Cần thêm `fetchOlderMessages()` + `ScrollController` bắt đỉnh danh sách. **~2h** |
| Xem ảnh đã gửi | dữ liệu có sẵn trong `ChatAttachment.isImage` | ✅ | ❌ | Tab "Ảnh" trong bottom sheet info — lọc `messages.where(a => a.isImage)`. **~1.5h** |
| Xem link đã gửi | — | ❌ | ❌ | **Không có API.** Phải regex `https?://` client-side trên nội dung tin. **~1h** |
| Ghim tin | `POST/DELETE .../pin` | ✅ | ✅ Đã có | — |

⚠️ **Cảnh báo về "xem ảnh/link đã gửi":** cả 2 chỉ chạy trên **các tin đã tải về local**. Nếu hội thoại có 5000 tin, user sẽ chỉ thấy ảnh của ~50 tin gần nhất.

→ **Đề xuất với Nhật:** bổ sung `GET /chat/conversations/{id}/attachments?type=image|link`. Không có nó thì tính năng chỉ đúng ~1% dữ liệu — nên gọi là "Ảnh gần đây" chứ không phải "Ảnh đã gửi".

> 🔴 **ĐÍNH CHÍNH (bản 21/07 lúc 15:0x — sai trong bản trước):**
> Bản đầu ghi "chưa wire `markRead()` và đổi tên hội thoại" — **SAI**.
> - `markRead()` **đã được gọi** trong `ChatProvider.openConversation()` (dòng 243) và `fetchMessages()` (dòng 359)
> - Đổi tên **đã có UI**: `_showRenameDialog()` tại `chat_screen.dart:576` → `updateConversation()` tại dòng 589
>
> **Nguyên nhân sai:** grep chỉ bắt pattern `chat.<method>(`, bỏ sót cách gọi `context.read<ChatProvider>().updateConversation()` và các lời gọi nội bộ trong provider. Đã kiểm tra lại bằng grep toàn `lib/`.

⚠️ **Còn thiếu wire thật sự:** `chat_screen.dart` chưa gọi `editMessage()`, `createGroup()`, `createPrivate()` — provider có nhưng UI bỏ trống. [P1]

### 3.4 "Cải thiện giao diện SOS" (mục 1.4)

Nhật nói "1 nút đang quá đơn giản". `sos_screen.dart` hiện đã 1481 dòng — có thể Nhật đang xem bản cũ trên `main` (branch `giap` chưa merge).

**Việc số 1: merge `giap` → `main` rồi mời Nhật xem lại.** Có thể yêu cầu này đã tự giải quyết.

Nếu vẫn cần nâng cấp, **2 endpoint SOS đang bỏ trống** đúng là phần làm màn SOS "dày" hơn:

| Endpoint | Trạng thái FE | Giá trị UI |
|---|---|---|
| `GET/PATCH /sos/settings` | ❌ **Chưa nối** | Màn "Cài đặt SOS": bật/tắt shake, ngưỡng, countdown, auto-call |
| `POST/PATCH/DELETE /sos/emergency-contacts` | ❌ Chỉ có `fetchEmergencyContacts()` (đọc) | Thêm/sửa/xóa liên hệ khẩn cấp ngay trong app |

> 📌 **Đính chính báo cáo 20/07:** dòng "SOS ✅ Done — settings đã nối" là **sai**. Grep `sos/settings` trong `lib/` = 0 kết quả. SOS đang ở mức **9/16 endpoint**.

Đề xuất UI: nút SOS giữ nguyên (khẩn cấp = phải đơn giản, không được thêm bước), nhưng bổ sung quanh nó — countdown 3s có thể hủy, danh sách liên hệ khẩn cấp, lịch sử cảnh báo, nút cài đặt.

---

## 4. Phân tích Face AI (mục 3–7 của Nhật)

### 4.1 ⚠️ Mâu thuẫn cần chốt ngay — số ảnh & cách upload

Nhật nói 3 điều **khác nhau** ở 3 chỗ:

| Nguồn | Nội dung |
|---|---|
| Chat mục 5 | "tầm 3–5 ảnh nhé ae" |
| Chat mục 6 | "đừng gửi 1 lượt, upload từng ảnh thôi" |
| Flow mục 7.1 | "User upload 2-3 ảnh rõ mặt" |
| **Swagger (nguồn chuẩn)** | `files`: array binary, **minItems 3, maxItems 5**, `multipart/form-data`, 1 request |

**Swagger bắt buộc gửi 3–5 file trong MỘT request** — không thể "upload từng ảnh" vì `minItems: 3` sẽ reject request 1 ảnh. Và "2-3 ảnh" cũng sai vì min là 3.

→ **`[VERIFY]` — chốt với Nhật:** giữ nguyên Swagger (FE gom 3–5 ảnh rồi submit 1 lần), hay BE sửa thành cho phép enroll tăng dần? FE sẽ code theo Swagger cho tới khi có phản hồi.

### 4.2 Gap: API không đủ cho flow Nhật mô tả

| Yêu cầu của Nhật | Endpoint tương ứng | Đánh giá |
|---|---|---|
| 7.1 Tạo Face Profile + 5 trạng thái | `POST /enroll`, `GET`, `PATCH enable/disable`, `DELETE` | ✅ Đủ. Nhưng `GET /face-profiles/{memberId}` trên Swagger có `responses: {200: {description: ""}}` — **không có schema**. FE không biết tên field trạng thái. `[VERIFY]` |
| 7.2 Trạng thái quét ảnh (6 trạng thái) | `GET /face-scan` | ⚠️ Không có schema response. `[VERIFY]` |
| 7.3 Xem gợi ý + độ tin cậy | `GET /face-suggestions` | ⚠️ Không có schema. Cần biết field `confidence` có tồn tại không |
| 7.4a Xác nhận | `POST .../confirm` | ✅ |
| 7.4b Từ chối | `POST .../reject` | ✅ |
| 7.4c **"Chọn thành viên khác"** | — | ❌ **Không có endpoint.** FE phải làm 2 bước: `reject` rồi `POST /tags` thủ công. Không atomic — nếu bước 2 fail thì gợi ý đã mất |
| 7.5 Tag thủ công | `POST /tags` (`taggedMemberId`, `tagNote`) | ✅ |
| 7.6 Filter album | xem bảng dưới | ⚠️ **Thiếu 2/5 filter** |
| 7.7 Gating theo gói | `featureAccess` | ⚠️ **Chưa biết tên key.** `[VERIFY]` |

**Chi tiết filter album (mục 7.6):**

| Filter Nhật yêu cầu | Query param có sẵn | OK? |
|---|---|---|
| Tất cả | (không param) | ✅ |
| Có tôi | `taggedMemberId=<myMemberId>` | ✅ |
| Theo từng thành viên | `taggedMemberId=<id>` | ✅ |
| **Chưa tag** | — | ❌ **Không có.** Cần `hasTags=false` hoặc `taggedMemberId=none` |
| **Có gợi ý AI** | — | ❌ **Không có.** Cần `hasSuggestions=true` hoặc `faceScanStatus=SUGGESTED` |

→ **Đề xuất với Nhật:** bổ sung 2 query param vào `GET /albums/media`. Lọc client-side không khả thi vì list đã phân trang (`page`/`limit`) — sẽ ra kết quả sai.

⚠️ `album_provider.fetchMedia()` hiện mới truyền 3/12 param Swagger hỗ trợ (`page`, `limit`, `mediaType`, `moderationStatus`). Thiếu `taggedMemberId`, `uploaderMemberId`, `visibilityScope`, `from`, `to`, `sortOrder`, `deletedView` → cần mở rộng trước khi làm filter.

### 4.3 Consent sinh trắc học — bắt buộc, không được bỏ qua

`consentConfirmed: boolean` là **required** trong `EnrollDto`. FE **phải** hiện dialog đồng ý rõ ràng trước upload, **không được auto-set `true`**. Đây là dữ liệu sinh trắc học — nếu Review 3 hỏi về quyền riêng tư thì đây là điểm cộng.

Nội dung dialog đề xuất:
> "Ảnh khuôn mặt của [Tên] sẽ được gửi lên máy chủ để tạo hồ sơ nhận diện. Hồ sơ này chỉ dùng để gợi ý gắn thẻ trong album gia đình, và có thể xóa bất cứ lúc nào. Bạn xác nhận đã được sự đồng ý của thành viên này?"

Lưu ý `DeleteFaceProfileDto` yêu cầu `confirmation: "DELETE_FACE_PROFILE"` → khi xóa phải bắt user gõ đúng chuỗi hoặc FE tự gửi kèm sau dialog xác nhận mạnh.

### 4.4 Vị trí đặt tính năng

Giữ nguyên kết luận 20/07: **`lib/screens/parent/member_detail_screen.dart`** (hiện 476 dòng, chỉ có phần tài chính) — thêm section "Hồ sơ khuôn mặt". Lý do: đã có sẵn `memberId` trong context, enroll là hành động quản trị per-member.

**File cần tạo mới:**

```
lib/models/face_profile.dart          — FaceProfile, FaceProfileStatus enum
lib/models/face_suggestion.dart       — FaceSuggestion, confidence, status
lib/providers/face_provider.dart      — 10 endpoint
lib/widgets/face_consent_dialog.dart  — dialog đồng ý sinh trắc học
lib/widgets/face_suggestion_card.dart — Xác nhận / Từ chối / Chọn người khác
```

---

## 5. Danh sách `[VERIFY]` — gửi Nhật

**Nhóm A — chặn Face AI (không có thì không code được):**

1. **Response schema của `GET /face-profiles/{memberId}`** — Swagger để trống. Xin 1 JSON thật. Tên field trạng thái? Enum gồm những giá trị nào (khớp 5 trạng thái mục 7.1)?
2. **Response schema của `GET /face-scan` và `GET /face-suggestions`** — có field `confidence` không? Kiểu gì (0–1 hay 0–100)?
3. **Chốt số ảnh enroll:** Swagger `min 3 / max 5` trong 1 request — có đúng không? Nếu muốn "upload từng ảnh" thì BE phải bỏ `minItems`.
4. **Tên key `featureAccess`** cho AI face suggestion (mục 7.7). Ví dụ `album.faceSuggestion`?
5. **Face scan tự động hay thủ công?** Upload xong BE tự quét, hay FE phải gọi `POST /face-scan`? (ảnh hưởng trực tiếp tới 6 trạng thái ở mục 7.2)

**Nhóm B — đề xuất bổ sung API:**

6. `GET /albums/media` — thêm param **`hasTags=false`** và **`hasSuggestions=true`** (mục 4.2). Không có thì filter "Chưa tag" / "Có gợi ý AI" không làm được.
7. Endpoint **đổi thành viên trong 1 suggestion** (reassign) — hiện phải reject + tag thủ công, không atomic.
8. `GET /chat/conversations/{id}/attachments?type=image|link` — cho mục 1.3.

**Nhóm C — tồn đọng từ 20/07, chưa có phản hồi:**

9. Schema `featureAccess` thật (key phẳng hay lồng) — **vẫn chặn gating toàn app**
10. API role / relationship / deputy permission — timeline?
11. FCM: `google-services.json` sai package (`com.company.familycare` ≠ `com.familycare.family_care`) + nghi Legacy API
12. `POST /auth/firebase` dùng làm gì?
13. `monthlyPrice` cho subscription plan (Duy cần để hiện "giảm 20%")

**Nhóm D — mới:**

14. **Có API cho trợ lý AI không?** Swagger không có endpoint nào. Nếu không có kế hoạch, FE sẽ làm rule-based đọc từ provider local (phương án A mục 2.4).

---

## 6. Backlog ưu tiên cập nhật

### P0 — hôm nay/mai
1. **Commit 6 file đang dirty + merge `giap` → `main`** (Duy đã nhắc nhiều lần)
2. ~~Chat: wire `markRead()`~~ — ✅ **đã có sẵn**, xem đính chính mục 3.3
3. ~~Chat: đổi tên hội thoại~~ — ✅ **đã có sẵn**
4. ✅ **AI Assistant: đã bỏ số liệu bịa** (21/07) — chuyển sang rule-based đọc `FinanceProvider` / `TaskProvider` / `CalendarProvider`. Đã sửa thêm 2 bug phát hiện khi review, xem mục 8.
5. **Gửi danh sách `[VERIFY]` mục 5 cho Nhật** — 5 câu nhóm A chặn toàn bộ Face AI

### P1 — tuần này
6. Chat: tab Ảnh + tab Link trong sheet info; load-more lịch sử theo cursor
7. SOS: nối `GET/PATCH /sos/settings` + CRUD emergency-contacts (7 endpoint còn thiếu)
8. Mở rộng `album_provider.fetchMedia()` đủ 12 query param
9. Face AI: dựng UI + provider skeleton (chưa gán API, chờ nhóm A) — theo đúng ý Duy "list flow trước"

### P2
10. Wearables: 6 endpoint `/wearables` chưa nối
11. Đổi tên `invitation_provider` → `join_request_provider`
12. Dọn hardcode hex → `AppColors` toàn app

---

## 7. Bảng độ phủ endpoint — FE Mobile (21/07)

| Module | Đã nối / Tổng | Ghi chú |
|---|---|---|
| Auth | 9/10 | Thiếu `/auth/firebase` |
| Finance (7 nhóm) | ~57/59 | Phủ rộng nhất |
| Tasks (6 nhóm) | ~42/44 | Đầy đủ |
| Chat | 15/18 | Provider 18/18, **UI thiếu 5 hàm** |
| Albums + Tags + Moderation | 14/14 | Nhưng filter mới dùng 3/12 param |
| Calendar | 7/7 | ✅ Mới xong |
| SOS | **9/16** | ❌ Thiếu settings ×2, emergency-contacts CRUD ×3 |
| Families + Join Requests | 14/14 | |
| Locations | 3/3 | |
| Notifications + Devices | 6/6 | Push đang chặn bởi BE |
| Subscriptions | 3/3 | Gating chưa làm |
| **Face Profiles + Face Suggestions** | **0/10** | ❌ Chưa bắt đầu |
| **Wearables** | **0/6** | ❌ Chưa bắt đầu |
| **AI Assistant** | **0/0** | Không có API |
| Admin | 0/47 | Ngoài scope (Duy) |

**Tổng scope mobile: ~179/213 ≈ 84%**

---

---

## 8. Review vòng 2 — `ai_assistant_screen.dart` (21/07, sau khi refactor)

**Kết quả tổng thể: đạt.** Đã bỏ sạch số liệu bịa, đọc dữ liệu thật từ 3 provider, có nhánh "chưa có dữ liệu" rõ ràng thay vì bịa số. `_assistantSurface` / `_assistantBorder` map đúng `AppColors.primary50` / `AppColors.progressTrack`.

Đã verify compile-safe: cả 3 provider (`FinanceProvider`, `TaskProvider`, `CalendarProvider`) đăng ký ở `MultiProvider` gốc trong `main.dart` (dòng 31/36/41) → `context.read` ở route `/ai` không throw. Các field truy cập (`models`, `budgetPlans`, `goals`, `monthlyFinance`, `loading`, `tasks`, `myAssignments`, `events`, `activeGoals`) đều tồn tại. `fetchAll()` / `fetchTasks()` / `fetchBootstrap()` đều bọc `try/catch` nội bộ → `initState` an toàn.

### 8.1 Bug đã sửa

**Bug 1 — `_money()` hỏng với số âm ≥ 6 chữ số** *(đã sửa)*

Dấu `-` bị đếm như một chữ số khi nhóm hàng nghìn:

```
-100000  →  "-.100.000đ"   ❌
-500000  →  "-.500.000đ"   ❌
-50000   →  "-50.000đ"     ✅ (đúng do tình cờ — nên rất khó phát hiện)
```

`balance = income - totalExpense` **có thể âm**, và mức âm ≥ 100.000đ là hoàn toàn bình thường với VND. Fix: tách dấu ra trước, nhóm trên `abs()`, ghép lại.

**Bug 2 — sai enum trạng thái assignment** *(đã sửa)*

Enum thật của `TaskAssignment` (`task_provider.dart:214`):
```
ASSIGNED | IN_PROGRESS | SUBMITTED | APPROVED | REJECTED | CANCELED | UNAVAILABLE
```
**Không có `PENDING`, không có `COMPLETED`.**

| Code cũ | Vấn đề |
|---|---|
| `active = status == 'PENDING' \|\| 'IN_PROGRESS'` | `'PENDING'` không tồn tại → **toàn bộ việc `ASSIGNED` (Chờ làm) bị đếm thiếu**. User có 5 việc chờ làm, bot báo "Đang/chờ làm: 0" |
| `done = 'APPROVED' \|\| 'COMPLETED'` | `'COMPLETED'` là nhánh chết (vô hại) |
| `'$done/${assignments.length}'` | Mẫu số gồm cả `CANCELED` / `UNAVAILABLE` → tỉ lệ hoàn thành bị pha loãng sai |

Fix: `'PENDING'` → `'ASSIGNED'`; loại `CANCELED`/`UNAVAILABLE` khỏi mẫu số; thêm dòng `REJECTED` (việc bị từ chối cần làm lại — trước đó biến mất hoàn toàn khỏi tóm tắt).

Nhánh fallback `tasks.tasks` dùng enum `FamilyTask` (`ACTIVE | COMPLETED | CANCELED`) — đã đúng, chỉ dọn nhánh chết `'APPROVED'`.

### 8.2 Còn lại — không chặn, cân nhắc trước Review 3

| # | Điểm | Mức |
|---|---|---|
| 1 | Câu fallback *"Tôi chưa có API chatbot riêng từ backend..."* lộ chi tiết nội bộ ra người dùng cuối. Đề xuất: *"Hiện tôi trả lời dựa trên dữ liệu trong ứng dụng: chi tiêu, nhiệm vụ, lịch và mục tiêu tiết kiệm."* | Thấp — nhưng supervisor sẽ nghe thấy câu này nếu gõ câu ngoài phạm vi |
| 2 | Keyword `'chi'` bắt trước `'tiết kiệm'` → *"mẹo tiết kiệm chi tiêu"* rơi vào nhánh tài chính. Đảo thứ tự check `_savingReply` lên trước `_financeReply` là xong | Thấp |
| 3 | Chưa có typing indicator / delay → bot trả lời tức thì, cảm giác giả lập. Thêm 300–500ms + 3 chấm động sẽ tự nhiên hơn | Cosmetic |
| 4 | Ký hiệu tiền `35.000.000đ` (không space). Kiểm tra khớp với format ở `wallet_screen` / `finance_reports_screen` để nhất quán toàn app | Thấp |

### 8.3 Đồng ý với 2 phản biện của bạn

- **Chat** — bạn đúng, tôi sai. Xem đính chính mục 3.3. Không có gì phải sửa.
- **Face AI** — đồng ý hoãn. 5 câu `[VERIFY]` nhóm A (mục 5) chưa có câu trả lời nào; code sâu bây giờ gần như chắc chắn phải viết lại. Dựng UI skeleton thì được, gán API thì không.
- **Git** — đúng, không tự commit/merge. Nhưng nhắc lại: `giap` đang ahead 16 / behind 11, cộng 6 file dirty. Đây vẫn là rủi ro số 1 của tuần.

### 8.4 Ghi chú về `flutter analyze`

Bạn báo "11 `info` cũ, không phát sinh mới" — 2 fix ở mục 8.1 là thay đổi logic thuần, không thêm import/API mới, nên số `info` giữ nguyên. **Cần chạy lại `flutter analyze lib` sau 2 fix này để xác nhận.**

---

> Mọi số liệu trong tài liệu này lấy từ `docs-json.json` (21/07) và grep trực tiếp `lib/`. Các mục `[VERIFY]` là điểm Swagger không khai báo schema hoặc mô tả của Nhật mâu thuẫn với Swagger — **chưa được suy đoán.**
