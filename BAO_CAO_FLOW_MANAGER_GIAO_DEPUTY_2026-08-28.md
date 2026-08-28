# Báo cáo: flow Manager giao việc cho Deputy — sai "Người làm / Người giao" và lỗi "Bad state"

- Ngày: 28/08/2026 · **Bản 4** (đã đối chiếu chat Discord 19/08 → 27/08, phản hồi BE 28/08, **và bản dump Swagger BE cập nhật 28/08**)
- Nhánh phân tích: `giap` @ `a3a3933` (đã đồng bộ `origin/main`)
- Nguồn hiện tượng: 2 ảnh chụp máy thật lúc **11:08** và **11:09** ngày 28/08
- Trạng thái: **mới phân tích source, chưa sửa dòng code nào**

---

## 1. Hai hiện tượng đang thấy

| # | Hiện tượng | Ảnh |
|---|---|---|
| H1 | Card danh sách nói `Người làm: Chưa giao cho ai`, nhưng mở chi tiết cùng task đó lại thấy `Phân công (1) — lê anh sĩ / Chờ làm` | ảnh 11:09 vs 11:08 |
| H2 | Bấm `Bắt đầu làm` → toast đỏ `Bad state: Công việc không còn ở trạng thái được giao.` | ảnh 11:08 |

Cả hai ảnh đều ở màn `Quản lý nhiệm vụ` (`task_management_screen.dart`) — màn này **dùng chung
cho Manager và Deputy**, không phải màn riêng của Deputy.

---

## 2. Chat Discord đã chốt những gì — các câu hỏi này KHÔNG hỏi lại nữa

Đọc lại toàn bộ trao đổi 19/08 → 27/08, BE đã trả lời dứt điểm 8 điểm dưới đây. Bản 1 của báo cáo
này có hỏi trùng vài mục — nay bỏ hết.

| # | Nội dung BE đã chốt | Ảnh hưởng tới ca đang điều tra |
|---|---|---|
| Đ1 | **Enum assignment chính thức, đúng 6 giá trị:** `ASSIGNED, IN_PROGRESS, SUBMITTED, APPROVED, REJECTED, CANCELED`. **Không có `PENDING`.** (Nhật, 14:38 + 14:55 ngày 26/08) | Thu hẹp mạnh phạm vi H2 — xem §4 |
| Đ2 | **`COMPLETED` là `TaskStatus` cấp task, KHÔNG phải status của assignment.** | Chip "Hoàn thành" của `test1052` là trạng thái task, không nói gì về phân công |
| Đ3 | **Assignment được tạo thẳng `ASSIGNED`**, kể cả recurring generation. `startAt` chỉ là mốc thời gian để hiển thị/lọc, **không có scheduler**, không có chuyển `PENDING → ASSIGNED`. | Sinh câu hỏi mới **C4** |
| Đ4 | **Quá hạn KHÔNG tự đổi status.** Assignment giữ nguyên status, BE trả thêm `isOverdue = true`. | Loại `EXPIRED`/`OVERDUE` khỏi danh sách nghi vấn của H2 |
| Đ5 | **Deputy bị chặn tự hưởng lợi ở BE:** không tự duyệt (reviewer ≠ `assignedTo`/`submittedBy`, sai thì **403**), không tự gia hạn/hủy/giao lại assignment của mình, không tự quản reward settlement của mình (mã ổn định `CANNOT_MANAGE_OWN_REWARD_SETTLEMENT`), không tự generate recurring cho chính mình. | Xác nhận dải "Bạn đang là người làm nhiệm vụ này…" trong ảnh là **đúng thiết kế** |
| Đ6 | **`GET /families/{id}/tasks` đã embed `rewardSetting`** (có thưởng → object, chưa đặt → `null`). Deploy 26/08, FE verify 27/08 (50/50 item). | Tiền lệ trực tiếp cho câu hỏi **B5** |
| Đ7 | **`GET /families/{id}/tasks/reward-settlements` đã embed `assignment`** gồm `id, assignedToMemberId, assignedByMemberId, status, assignedAt, startAt, dueAt, assignedToMember, assignedByMember`. | Tiền lệ thứ hai cho **B5** — BE đã làm đúng việc này cho một endpoint khác rồi |
| Đ8 | Mã lỗi ổn định đã có: `SUBMISSION_OVERDUE` (400), `CANNOT_MANAGE_OWN_REWARD_SETTLEMENT`. Submission có `submittedAt` + `isLate`. `GET submissions` sort `submittedAt desc`. `proofs: []` không hợp lệ (min 1). | Xác nhận BE sẵn sàng cấp mã lỗi ổn định khi FE xin → củng cố **B3** |

**Đ1 là điểm quan trọng nhất.** Bản 1 của báo cáo lo rằng BE có thể đã thêm status mới nào đó khiến
FE vẽ nhầm thành "Chờ làm". Enum đã được chốt cứng 2 lần trong chat, nên khả năng đó **loại bỏ được**
— và nhờ vậy §4 dưới đây thu hẹp còn đúng một nghi phạm.

### Phản hồi BE ngày 28/08 — trả lời trực tiếp báo cáo bản 2

BE đã đối chiếu code và trả lời **4/6 câu nhóm B**. Nay đóng luôn:

| # | BE trả lời | Đóng câu |
|---|---|---|
| Đ9 | **`GET /tasks/{taskId}/assignments` có lọc theo vai, nhưng chỉ chặn `FAMILY_MEMBER`:** `FAMILY_MANAGER` và `DEPUTY_MEMBER` xem **toàn bộ** assignment của task; `FAMILY_MEMBER` **chỉ xem assignment của chính mình**. | **B1** — và mở ra **GT-3**, xem §4 |
| Đ10 | **Không tự lọc bỏ `CANCELED`** nếu FE không truyền `status`. | **B2** |
| Đ11 | `PATCH /assignments/{id}/start` **chỉ hợp lệ khi status = `ASSIGNED`**, khác thì **400**. BE sẽ bổ sung mã ổn định **`ASSIGNMENT_NOT_STARTABLE`**. | **B3** |
| Đ12 | BE sẽ **bổ sung assignments summary vào `GET /families/{familyId}/tasks`, hoặc cấp bulk endpoint** để FE bỏ N+1. | **B5** ✅ *(mục đáng giá nhất — gỡ luôn L4 và phần lớn L3)* |

BE kết luận: *"giả thuyết Deputy bị BE lọc role nên list assignment rỗng hiện không khớp code BE,
**nếu account thật sự là `DEPUTY_MEMBER`**"* — và yêu cầu FE gửi response thô nếu vẫn tái hiện được.
Vế điều kiện in đậm chính là chỗ cần kiểm, xem GT-3.

### Đối chiếu bản dump Swagger 28/08 — xác nhận bằng contract, không còn là lời nói

Swagger nay **đã có response schema đầy đủ cho nhóm Phân công** (trước đây `"200": {"description": ""}`,
chính là mục Duy phàn nàn 19/08 làm mất cả buổi mới tìm ra lỗi). Kết quả đối chiếu:

| # | Swagger nói gì | Ý nghĩa |
|---|---|---|
| Đ13 | `TaskAssignmentResponseDto.status` enum đúng **6 giá trị**, không có `PENDING`. `isOverdue` là field **bắt buộc**. | Chốt cứng Đ1 + Đ4 bằng schema |
| Đ14 | `GET /tasks/{taskId}/assignments`: *"Quản lý và phó thành viên xem tất cả phân công của công việc; thành viên thường chỉ xem phân công của chính mình."* | Đ9 nay là **contract chính thức**, không phải mô tả miệng → GT-3 có cơ sở vững |
| Đ15 | `GET /tasks/assignments/{assignmentId}` áp **cùng quy tắc lọc vai** đó. | Quan trọng: nếu tài khoản là `FAMILY_MEMBER`, endpoint chi tiết **vẫn trả** phân công của chính họ → khớp đúng việc sheet hiện `Phân công (1)` cho `test1108` |
| Đ16 | `PATCH /assignments/{id}/start` → `400 "Chỉ có thể bắt đầu công việc đang ở trạng thái được giao"`, **chưa có `code`/`errorCode`**. | `ASSIGNMENT_NOT_STARTABLE` BE hứa ở Đ11 **chưa deploy** → mục 7 ở §7 vẫn phải chờ |
| Đ17 | `GET /families/{familyId}/tasks` vẫn `"200": {"description": ""}` — **không** thấy `rewardSetting`, **không** thấy `assignments`. `GET /tasks/reward-settlements` cũng vậy. | Đ6/Đ7 đã chạy thật (FE verify 27/08) nhưng **chưa được document**; Đ12 **chưa implement** |

Ba điểm phụ cũng rút ra từ schema, ảnh hưởng tới code FE — xem **L7**.

---

## 3. Phần đã kết luận chắc từ source — KHÔNG cần hỏi ai

Năm lỗi dưới đây đọc code là thấy, không phụ thuộc dữ liệu runtime.

### L1 — Chuỗi `Bad state:` là nội bộ Dart lọt thẳng ra người dùng

[`task_provider.dart:1092`](lib/providers/task_provider.dart:1092) ném `StateError`. Chỗ bắt ở
[`task_management_screen.dart:1384`](lib/screens/parent/task_management_screen.dart:1384) chỉ cắt
tiền tố `'Exception: '`:

```dart
e.toString().replaceFirst('Exception: ', '')
```

`StateError.toString()` cho ra `Bad state: <message>` → tiền tố không bị cắt, hiện nguyên trên toast.
Lỗi hiển thị thuần FE.

### L2 — Nút "Bắt đầu làm" hiện lên rồi mới tự báo lỗi

Nút chỉ vẽ khi `a.status == 'ASSIGNED'`
([`:1348`](lib/screens/parent/task_management_screen.dart:1348)), lấy từ **cache**.
`startAssignment()` sau đó GET lại chi tiết và ném lỗi nếu status thật ≠ `ASSIGNED`
([`task_provider.dart:1090-1093`](lib/providers/task_provider.dart:1090)). Cache và server lệch nhau,
UI để người dùng bấm vào một nút chắc chắn thất bại.

### L3 — Đường cứu lỗi trong `catch` bị vô hiệu hóa âm thầm ⚠️ **nghi là nguyên nhân chính**

`ensureAssignmentsFor()` đánh dấu **toàn bộ** taskId vào `_assignmentsInFlight` ngay từ đầu
([`task_provider.dart:983`](lib/providers/task_provider.dart:983)), rồi mới xử lý từng cái một, và
chỉ gỡ đánh dấu ở `finally` khi đã chạy xong hết.

Trong khi đó `fetchTaskAssignments()` mở đầu bằng
([`task_provider.dart:918`](lib/providers/task_provider.dart:918)):

```dart
if (isFullList && _assignmentsInFlight.contains(taskId)) return;
```

Hệ quả: suốt thời gian preload chạy, **mọi lời gọi `fetchTaskAssignments()` đều return ngay, không
làm gì**. Ba chỗ bị ảnh hưởng:

- mở sheet chi tiết ([`:694`](lib/screens/parent/task_management_screen.dart:694)) → sheet vẽ bằng cache cũ;
- `catch` của nút Bắt đầu ([`:1379`](lib/screens/parent/task_management_screen.dart:1379)) → dòng không được làm mới, **bấm lại vẫn ăn đúng lỗi cũ, lặp vô hạn** — đúng thứ mà comment ở `:1376-1378` tưởng mình đang tránh;
- sau khi hủy phân công ([`:1190`](lib/screens/parent/task_management_screen.dart:1190)).

### L4 — Cửa sổ preload dài 35–50 giây

[`task_provider.dart:949-950`](lib/providers/task_provider.dart:949): `_assignmentBatch = 1`,
`_assignmentRequestSpacing = 350ms`. Màn này gọi `ensureAssignmentsFor(..., forceRefresh: true)`
cho **tất cả** task ở cả `initState` ([`:75`](lib/screens/parent/task_management_screen.dart:75))
lẫn pull-to-refresh ([`:381`](lib/screens/parent/task_management_screen.dart:381)).

Gia đình trong ảnh có **67 task** → 67 request tuần tự × (RTT + 350ms) ≈ **35–50 giây**, cộng
backoff 1s/2s mỗi lần dính 429/502. Trong toàn bộ cửa sổ đó L3 có hiệu lực. Gốc rễ là N+1 do
`GET /tasks` không kèm assignment (xem **B5**).

### L5 — Sheet và card đếm phân công theo hai quy tắc khác nhau ⚠️ **khớp đúng cặp ảnh**

| Nơi | Quy tắc |
|---|---|
| Sheet `Phân công (N)` ([`:886`](lib/screens/parent/task_management_screen.dart:886), [`:913`](lib/screens/parent/task_management_screen.dart:913)) | đếm **tất cả**, kể cả `CANCELED` |
| Card `Người làm:` ([`:3516`](lib/screens/parent/task_management_screen.dart:3516)) | `where(status != 'CANCELED')` |

Nên một task chỉ còn phân công đã hủy sẽ hiện **đồng thời** `Phân công (1)` ở sheet và
`Chưa giao cho ai` ở card. Card còn bỏ qua bản ghi có `assignedToMemberId` rỗng
([`:3524-3526`](lib/screens/parent/task_management_screen.dart:3524)), sheet thì không.

### L6 — Nhánh mặc định `_ => 'Chờ làm'` giờ là rủi ro thuần, không còn lợi ích

[`task_provider.dart:411-420`](lib/providers/task_provider.dart:411) dịch mọi status lạ thành
"Chờ làm"; [`:383`](lib/providers/task_provider.dart:383) thiếu hẳn field `status` thì mặc định
`'ASSIGNED'`.

Sau Đ1, enum đã chốt cứng 6 giá trị và FE phủ đủ cả 6. Nghĩa là nhánh mặc định **không bao giờ chạy
đúng nữa** — nó chỉ còn tác dụng che một vi phạm contract và biến nó thành nút "Bắt đầu làm" hỏng.
Nên đổi thành hiện status thô + **không** dựng nút hành động.

Ghi chú dọn dẹp: comment ở [`task_provider.dart:1089`](lib/providers/task_provider.dart:1089) vẫn
viết "khi assignment vẫn PENDING" — sai theo Đ1. Code không dùng `PENDING` cho assignment ở đâu cả,
chỉ còn comment và `API_DOCS.md` (xem §6).

### L7 — Ba nhánh parse phòng thủ nay đã chết, đối chiếu schema mới 🆕

`TaskAssignment.fromJson` ([`task_provider.dart:329`](lib/providers/task_provider.dart:329)) được viết
hồi Swagger còn trống schema nên đoán nhiều biến thể. Nay có
`TaskAssignmentResponseDto` thật, ba nhánh sau **không bao giờ trúng**:

| Nhánh đang đọc | Schema thật | Kết luận |
|---|---|---|
| `member['displayName']` | `TaskAssignmentMemberSummaryResponseDto` không có `displayName`; tên ở `user.fullName` (FE đọc trước rồi) | **GIỮ** — `GET /tasks/reward-settlements` embed `assignedToMember` **có** `displayName` (Đ7), nên nhánh này sống ở đường khác. Bản 3 của báo cáo nói nó "chết" là sai. |
| `taskMap?['createdByMemberId']` | `TaskAssignmentTaskSummaryResponseDto` không có field này | Chết ở nhóm endpoint phân công, nhưng vô hại và sẽ sống lại nếu BE làm giàu `task`. **GIỮ**, chỉ ghi rõ trong doc comment. |
| `j['rewardSetting']` | Không có trong `TaskAssignmentResponseDto` → luôn `null` | **GIỮ** vì lý do như trên. |

→ Quyết định khi sửa: **không xoá nhánh nào**. Gỡ một fallback chỉ để cho gọn mà làm hỏng đường
reward-settlement thì lỗ nặng hơn lãi. Thay vào đó ghi thẳng schema thật vào doc comment của
[`status`](lib/providers/task_provider.dart:298) để lần sau đọc code không tưởng BE trả những field đó.

Ngược lại, có **một field BE trả mà FE bỏ qua**: `assignedAt` (bắt buộc trong schema). Hiện
`_assignmentPeriodLine` ([`task_management_screen.dart:569`](lib/screens/parent/task_management_screen.dart:569))
trả `null` khi cả `startAt` lẫn `dueAt` đều rỗng — đúng ca `test1108` trong ảnh, dòng thời gian biến
mất hoàn toàn. Dùng `assignedAt` làm mốc dự phòng thì task định kỳ 30 phân công không còn trông y hệt
nhau.

---

## 4. Giả thuyết nguyên nhân — sau Đ1 chỉ còn 2, và một cái đã rất mạnh

Sau khi enum được chốt, status thật của phân công lúc bấm nút chỉ có thể là 1 trong 5 giá trị còn
lại. Chiếu từng cái vào **cả H1 lẫn H2**:

| Status thật | Gây ra H2 (`Bad state`)? | Gây ra H1 (`Chưa giao cho ai`)? | Kết luận |
|---|---|---|---|
| `IN_PROGRESS` | có | **không** — card vẫn hiện tên | loại |
| `SUBMITTED` | có | **không** | loại |
| `APPROVED` | có | **không** | loại |
| `REJECTED` | có | **không** — còn hiện nút "Nộp lại" | loại |
| **`CANCELED`** | **có** | **có** — bị lọc ở [`:3516`](lib/screens/parent/task_management_screen.dart:3516) | **khớp cả hai** |

**GT-1 — Phân công đã bị hủy + cache lệch (thuần FE).** Cache còn `ASSIGNED` cũ → sheet vẽ "Chờ làm"
+ nút Bắt đầu → `getAssignmentDetail` đọc status thật `CANCELED` → ném lỗi, đồng thời ghi status mới
vào cache qua `_upsertAssignmentInTaskCache` → quay ra card, bản ghi bị lọc → `Chưa giao cho ai`.
Khớp trọn vẹn cả hiện tượng lẫn thứ tự thời gian 11:08 → 11:09. **Sửa hoàn toàn ở FE.**

**GT-2 — BE lọc `DEPUTY_MEMBER` khi đọc danh sách phân công. ❌ ĐÃ LOẠI.** Đ9 nói rõ Deputy xem được
toàn bộ, y như Manager. Đ10 cũng loại nốt khả năng BE tự giấu bản ghi `CANCELED`.

**GT-3 — Tài khoản trong ảnh thực chất là `FAMILY_MEMBER`, không phải `DEPUTY_MEMBER`. 🆕**
Đ9 để lộ một nhánh không ai để ý: BE **có** lọc theo vai, chỉ là chặn ở `FAMILY_MEMBER` — vai này
chỉ đọc được assignment của **chính mình**. Nếu tài khoản đang đăng nhập là `FAMILY_MEMBER` thì:

- `test1052`, `[REC-MGR-DEP] 032444` giao cho người khác → BE trả `[]` → card nói `Chưa giao cho ai`. **Giải thích được đúng chỗ GT-1 bó tay.**
- `test1108` giao cho chính người này → BE trả 1 bản ghi → sheet hiện `Phân công (1)`, và nút `Bắt đầu làm` hiện ra vì đúng là việc của mình.

Đ14 + Đ15 nâng GT-3 từ suy đoán thành **giả thuyết có contract chống lưng**: Swagger nay ghi rõ quy
tắc lọc vai này ở **cả hai** endpoint, và chính vì endpoint chi tiết vẫn trả phân công *của chính
mình* nên sheet mới hiện được `Phân công (1)` trong khi card thì trống.

GT-3 giải thích H1 trọn vẹn hơn GT-1, nhưng **không tự nó giải thích H2** — vẫn cần status thật là
`CANCELED` (hoặc một status ≠ `ASSIGNED`) để `start` ném lỗi. Nhiều khả năng **GT-1 + GT-3 cùng đúng**:
vai `FAMILY_MEMBER` làm hỏng cột "Người làm" của cả danh sách, còn phân công của `test1108` thì đã bị
hủy từ trước và cache còn giữ `ASSIGNED` cũ.

Vướng mắc của GT-3: theo `app_router.dart`, `FAMILY_MEMBER` **không được vào** `/manager/tasks` —
router cô lập shell theo vai. Nên nếu GT-3 đúng thì còn một lỗ hổng điều hướng nữa phải tìm. Cũng có
thể vai trên BE và vai FE đang giữ trong `AuthProvider` **lệch nhau** (vd vừa đổi vai mà phiên chưa
làm mới) — trường hợp đó FE nghĩ mình là Deputy, BE xử theo Member.

Chi tiết ủng hộ cả GT-1 lẫn GT-3: card hiện `Hạn 29/08 11:08` cho `test1108`. Theo
[`:3548-3560`](lib/screens/parent/task_management_screen.dart:3548) hạn của assignment được **ưu
tiên** hơn hạn task; hiện ra hạn task nghĩa là lúc vẽ card, danh sách assignment đúng là rỗng thật.

→ **Phép thử phân định giờ là A2 + A8**, không còn là A6. Chỉ cần biết `familyRole` thật của tài
khoản trên BE là tách được GT-1 với GT-3.

---

## 5. DANH SÁCH CÂU HỎI (bản rút gọn — đã bỏ mọi câu chat đã trả lời)

### Nhóm A — Hỏi người test / Duy (người chụp 2 ảnh)

**A1. Ảnh chụp trên bản build nào?**
Commit `a3a3933` được tạo lúc **11:21** ngày 28/08, tức **sau** giờ chụp ảnh (11:08/11:09). Vậy 2 ảnh
này chụp trên bản build cũ hơn, hay đã cài lại bản mới rồi chụp?
→ Trả lời: `git rev-parse --short HEAD` của bản đã cài + giờ cài. Không nhớ thì chỉ cần: "bản trước 11:21" hay "bản sau 11:21".

**A2. Tài khoản đang đăng nhập lúc chụp là ai, vai gì?** ⭐ **CÂU QUAN TRỌNG NHẤT SAU PHẢN HỒI BE**
Đ9 cho biết `FAMILY_MEMBER` chỉ đọc được assignment của chính mình, còn Deputy đọc được hết. Nên chỉ
riêng câu này đã tách được GT-1 với GT-3 (§4).
→ Trả lời: email + vai **lấy từ BE**, không lấy từ giao diện app. Cách chắc nhất: gọi
`GET /families/{familyId}/members` bằng token của chính tài khoản đó rồi đọc `familyRole` của mình,
hoặc nhờ BE tra DB theo email. Nếu vai trên BE là `FAMILY_MEMBER` mà app vẫn vào được màn Quản lý
nhiệm vụ thì đó là lỗi thứ hai, báo lại ngay.

**A3. "lê anh sĩ" có phải chính tài khoản đang đăng nhập không?**
Nút `Bắt đầu làm` chỉ hiện khi phân công là của **chính người đang đăng nhập**
([`:1339`](lib/screens/parent/task_management_screen.dart:1339)), và dải "Bạn đang là người làm
nhiệm vụ này…" chỉ hiện khi **không phải Manager**
([`:725-732`](lib/screens/parent/task_management_screen.dart:725)). Tức app đang tin người đăng nhập
là Deputy tên lê anh sĩ.
→ Trả lời: đúng / sai. Nếu **sai** thì đây là lỗi nhận nhầm danh tính, nghiêm trọng hơn nhiều — báo lại ngay.

**A4. Trước khi chụp ảnh 11:08, phân công cho lê anh sĩ đã bị ai bấm hủy (nút ✕) hoặc giao lại chưa?**
Kể cả trên thiết bị khác / tài khoản Manager. **Đây là câu xác nhận trực tiếp cho GT-1.**
→ Trả lời: có / không / không rõ.

**A5. Từ lúc mở màn `Quản lý nhiệm vụ` đến lúc bấm `Bắt đầu làm` là bao lâu?**
Dưới 1 phút thì rơi đúng cửa sổ preload 35–50s ở L4 → củng cố GT-1.
→ Trả lời: ước lượng theo giây.

**A6. Chờ đứng yên ~1 phút rồi kéo refresh lại thì card có tự hiện đúng tên người làm không?** ⭐
Phép thử phân định: **hiện đúng ⇒ GT-1 (lỗi FE), vẫn "Chưa giao cho ai" ⇒ GT-2 (lỗi BE)**.
→ Trả lời: hiện đúng / vẫn sai + ảnh chụp.

**A7. Chụp `adb logcat` trong lúc tái hiện — BE đã yêu cầu đích danh gói dữ liệu này.** ⭐
Lệnh: `adb logcat | grep -iE "flutter|TaskProvider|ApiClient|Exception"`.
BE cần **response thô** của đúng 2 request:

- `GET /families/{familyId}/tasks/{taskId}/assignments?limit=100`
- `GET /families/{familyId}/tasks/assignments/{assignmentId}`

kèm `familyId`, `taskId`, `assignmentId`, email account, `familyRole`.
→ Trả lời: dán nguyên body + status code của cả hai. Đây là gói duy nhất BE còn thiếu để chốt.

**A8. `test1052` đang là "Hoàn thành" mà card nói "Chưa giao cho ai" — mở sheet task đó ra thì thấy gì?**
Đây là mảnh dữ liệu duy nhất GT-1 không giải thích được (§4).
→ Trả lời: ảnh chụp sheet `Phân công (N)` của `test1052`.

---

### Nhóm B — Hỏi team Backend (Nhật)

> ~~B1~~ ✅ đã trả lời + đã vào Swagger (Đ9/Đ14) · ~~B2~~ ✅ (Đ10).
> **B3 và B5 đã được BE nhận làm nhưng đối chiếu Swagger 28/08 thì CHƯA deploy** (Đ16, Đ17) — giữ lại
> để theo dõi, chỉ cần BE báo mốc thời gian.

**B4. `GET /tasks/{taskId}/assignments` và `GET /tasks/assignments/{assignmentId}` có thể trả `status` khác nhau cho cùng một bản ghi không?**
Vd do cache, replica đọc chậm, hay hai service khác nhau. Đây chính là cơ chế sinh ra lỗi trong ảnh
nếu GT-1 đúng.
→ Trả lời: có / không. Nếu có thì độ trễ tối đa bao nhiêu.

**B5. ⏳ BE ĐÃ NHẬN LÀM (Đ12) NHƯNG CHƯA THẤY TRONG SWAGGER (Đ17) — giữ đặc tả để khỏi hỏi lại shape**
BE trả lời sẽ *"bổ sung assignments summary vào `GET /families/{familyId}/tasks` hoặc cung cấp bulk
endpoint để FE bỏ N+1"*. Đây là mục đáng giá nhất trong cả báo cáo: nó xoá luôn L4 và phần lớn L3.
Bản dump 28/08 vẫn để `GET /tasks` ở `"200": {"description": ""}` nên FE chưa thể dựa vào.

→ Shape FE mong muốn, mỗi item của `GET /tasks` thêm:

```jsonc
"assignments": [
  {
    "id": "...",
    "assignedToMemberId": "...",
    "assignedToMember": { "id": "...", "user": { "fullName": "..." } },
    "assignedByMemberId": "...",
    "status": "ASSIGNED",
    "startAt": "...",
    "dueAt": "...",
    "isOverdue": false
  }
]
```

Chưa giao cho ai thì trả `[]` (**không phải `null`**, để FE phân biệt "đã tải, rỗng thật" với "chưa
tải"). Sợ payload phồng thì chấp nhận bản rút gọn chỉ gồm
`id, assignedToMemberId, assignedToName, status, dueAt`. Chọn hướng bulk endpoint thì FE xin dạng
`GET /families/{familyId}/tasks/assignments?taskIds=a,b,c`.
→ Còn cần BE cho biết: **chọn hướng nào** (embed hay bulk) và **thời điểm deploy dự kiến**, để FE
biết nên vá tạm N+1 hay chờ.

**B7. `assignments` embed ở Đ12 có áp dụng cùng quy tắc lọc theo vai như Đ9 không?** 🆕
Tức `FAMILY_MEMBER` gọi `GET /tasks` thì mỗi item chỉ kèm assignment của chính mình, còn
Manager/Deputy kèm đủ? FE cần biết trước để không lặp lại đúng lỗi "Chưa giao cho ai" trên endpoint
mới.
→ Trả lời: cùng quy tắc / khác (nói rõ).

**B8. `GET /families/{familyId}/tasks` và `GET /tasks/reward-settlements` bao giờ có response schema?** 🆕
Hai endpoint này vẫn là `"200": {"description": ""}` trong bản dump 28/08, dù BE đã thực sự thêm
`rewardSetting` (Đ6) và `assignment` (Đ7) vào chúng và FE đã verify chạy thật. Nhóm Phân công vừa được
bổ sung schema rất tốt — xin làm nốt hai chỗ này để FE kiểm được contract bằng Swagger thay vì bấm tay.
→ Trả lời: có kế hoạch / không.

**B6. Rate limit thật của nhóm endpoint assignment là gì?**
FE đang phải bóp còn **1 request / 350ms** vì log máy thật 28/08 cho thấy 4 request song song bị
chặn hàng loạt. Con số này FE đặt bằng cách mò, không theo tài liệu nào.
→ Trả lời: số request/giây/tài khoản, mã trả về khi vượt (`429`? `502`?), có header `Retry-After` không.

---

### Nhóm C — Hỏi Product / cả nhóm (quyết định nghiệp vụ)

**C1. Phân công đã `CANCELED` thì card danh sách nên hiện gì?**
Card nói `Chưa giao cho ai` — đúng nghiệp vụ nhưng mâu thuẫn thị giác với sheet đang đếm cả phân
công đã hủy (L5).
→ Chọn 1: (a) card giữ "Chưa giao cho ai" **và** sheet bỏ đếm bản ghi `CANCELED`; (b) cả hai cùng hiện "Đã hủy — chưa giao lại"; (c) sheet tách riêng mục "Đã hủy".

**C2. Deputy có được thấy toàn bộ phân công của task do Manager tạo không?**
Quyết định B1 nên trả lời thế nào. Chat mới chỉ chốt quyền **ghi**, chưa chốt quyền **đọc**.
→ Chọn 1: (a) Deputy thấy hết như Manager; (b) Deputy chỉ thấy phân công mình tạo hoặc mình nhận.

**C3. Deputy tự bắt đầu / tự nộp việc được giao cho chính mình — đúng ý product chứ?**
Ranh giới hiện tại: cấm hành vi **quản lý**, cho phép hành vi **thực thi**. Khớp với Đ5 (BE cấm tự
duyệt, tự gia hạn, tự hủy, tự quản thưởng — nhưng không cấm tự bắt đầu/tự nộp).
→ Trả lời: đúng / cần siết thêm (nói rõ hành vi nào).

**C4. FE đang chặn bắt đầu việc trước `startAt`, còn BE thì không — giữ hay bỏ?** 🆕
Theo Đ3, BE tạo assignment thẳng ở `ASSIGNED` và coi `startAt` **chỉ là mốc hiển thị/lọc**, không có
scheduler, không chặn gì. Nhưng commit `a3a3933` vừa thêm `isAssignmentNotStarted()` ở FE
([`task_provider.dart:33`](lib/providers/task_provider.dart:33)) **ẩn nút Bắt đầu/Nộp** cho tới đúng
giờ `startAt`. Tức FE đang **nghiêm hơn BE**: gọi thẳng API thì BE cho qua, bấm trong app thì không.
Việc này quan trọng với task định kỳ Manager giao Deputy — đúng flow đang điều tra.
→ Chọn 1: (a) đúng ý product, giữ chặn ở FE và **xin BE chặn nốt ở server** cho nhất quán; (b) không cần chặn, FE gỡ `isAssignmentNotStarted()`.

**C5. Deputy có được giao việc cho Manager không?** 🆕
Nhật đã nêu trong chat 26/08 là **"cần BE/Product chốt, hiện code chưa thấy chặn"** — tới giờ chưa ai
trả lời. Ma trận FE đề xuất còn lại đã thống nhất: Manager → Member/Deputy/chính Manager (cả `AD_HOC`
lẫn `RECURRING`); Deputy → Member; Deputy → chính Deputy: không.
→ Trả lời: cho / không cho. Nếu không cho thì xin BE chặn + cấp mã lỗi ổn định, FE ẩn tên Manager trong sheet "Giao việc cho".

---

## 6. `API_DOCS.md` đang lệch so với chat — cần cập nhật

Theo Rule 1 của repo, những mục dưới đây phải được ghi vào `API_DOCS.md`. Grep hiện tại **không thấy**
mục nào trong số này:

| Nội dung | Nguồn | Trạng thái trong `API_DOCS.md` |
|---|---|---|
| `GET /tasks` trả kèm `rewardSetting` (`null` nếu chưa đặt) | Đ6, deploy 26/08 | thiếu |
| `GET /tasks/reward-settlements` trả kèm `assignment` | Đ7 | thiếu |
| Mã lỗi `CANNOT_MANAGE_OWN_REWARD_SETTLEMENT` | Đ5/Đ8 | thiếu |
| Review submission: reviewer ≠ `assignedTo`/`submittedBy` → **403** | Đ5 | thiếu |
| Submission có `submittedAt` + `isLate`; `GET submissions` sort `submittedAt desc`; `proofs` min 1 | Đ8 | thiếu |
| `confirm-received` tạo `LedgerEntry` `entryType=REWARD`, `sourceType=TASK_REWARD_SETTLEMENT`, `sourceId=settlementId`, idempotent; **chỉ áp dụng cho lần confirm sau deploy** | Nhật 21:56 ngày 27/08 | thiếu |
| Assignment: `startAt`/`dueAt`/`isOverdue`; quá hạn **không** đổi status | Đ3/Đ4 | thiếu |
| **Quy tắc lọc vai khi đọc phân công**: Manager/Deputy xem hết, `FAMILY_MEMBER` chỉ xem của mình — áp cho **cả** `GET /tasks/{taskId}/assignments` lẫn `GET /tasks/assignments/{assignmentId}` | Đ14/Đ15 (Swagger) | thiếu — **mục quan trọng nhất cần thêm** |
| Schema `TaskAssignmentResponseDto`: `assignedAt` (bắt buộc), `assignedToMember`/`assignedByMember` nullable với shape `{id, userId, familyRole, status, user{id, fullName, avatarUrl}}`, `task` là bản rút gọn **không kèm** `createdByMember` | Swagger 28/08 | thiếu |
| Danh sách phân công trả `{items, total, page, limit, totalPages}`, `limit` mặc định 20 / tối đa 100 | Swagger 28/08 | thiếu |
| `PATCH /assignments/{id}/start` hiện trả 400 **không kèm mã ổn định**; `ASSIGNMENT_NOT_STARTABLE` mới là lời hứa, chưa deploy | Đ11 + Đ16 | thiếu |
| `ResolveRewardDisputeDto` chỉ có `action`, **chưa có** `resolutionNote` | Swagger 28/08 | thiếu |

Hai dòng **sai** cần sửa:

- [`API_DOCS.md:638`](API_DOCS.md:638) — ghi cancel assignment "chỉ khi **PENDING**/IN_PROGRESS". Theo Đ1 không có `PENDING`; code FE dùng đúng `ASSIGNED || IN_PROGRESS` ([`:1182`](lib/screens/parent/task_management_screen.dart:1182)). Sửa thành `ASSIGNED | IN_PROGRESS`.
- [`API_DOCS.md:636`](API_DOCS.md:636) — ghi `getAssignmentDetail()` "chưa có UI gọi (còn dư)". Nay đã được `startAssignment()` gọi mỗi lần bấm Bắt đầu ([`task_provider.dart:1090`](lib/providers/task_provider.dart:1090)) — chính là nguồn của H2.

---

## 7. Sau khi có trả lời thì làm gì

### ✅ ĐÃ SỬA (28/08) — thuần FE, BE cũng chủ động yêu cầu đúng 4 mục đầu

Verify: `flutter analyze --no-fatal-infos` **0 error** (21 info có sẵn, không phát sinh mới) ·
`flutter test` **626/626 pass** (+4 test mới) · `git diff --check` pass.

1. **L1** — `startAssignment` ném `Exception` thay `StateError`, message nêu đúng trạng thái thật ("…đang ở trạng thái «Đã hủy»"). Hết chuỗi `Bad state:`.
2. **L3** — tách `_assignmentsInFlight` (chỉ id **đang thật sự có request bay**, add/remove quanh đúng lời gọi HTTP) khỏi `_assignmentsPreloadQueued` (hàng đợi preload, chỉ để `ensureAssignmentsFor` tự dedupe). Backoff retry nằm ngoài khối in-flight. `_loadAssignmentsQuiet` nhường task nào người dùng đang tự nạp. **Mục đáng giá nhất** — chữa cả sheet vẽ dữ liệu cũ lẫn vòng lặp bấm-lại-lỗi-y-hệt.
3. **L5** — sheet lọc `CANCELED` giống card, số phân công đã hủy hiện thành dòng riêng "+ N phân công đã hủy". Hai màn không còn nói ngược nhau. *(Vẫn chờ C1 nếu product muốn phương án (b)/(c).)*
4. **L6** — `labelOf` mặc định → "Không rõ trạng thái"; `fromJson` thiếu `status` → chuỗi rỗng thay vì đoán `ASSIGNED`; thêm `hasKnownStatus` + `knownStatuses`. Bỏ `UNAVAILABLE` khỏi bảng nhãn/màu (không phải status của assignment). Nút hành động vốn đã gate bằng so sánh tường minh nên tự động không hiện với status lạ.
5. **L7** — thêm parse `assignedAt` và dùng làm mốc dự phòng ở `_assignmentPeriodLine` ("Giao lúc dd/MM HH:mm"). Ba nhánh fallback **giữ nguyên**, lý do ở L7.
6. `API_DOCS.md` — sửa 2 dòng sai (`PENDING` ở cancel, ghi chú "chưa có UI gọi" của `getAssignmentDetail`) và bổ sung: quy tắc lọc theo vai khi đọc phân công, schema `TaskAssignmentResponseDto`, phân trang, `rewardSetting` trong `GET /tasks`, `assignment` trong reward-settlements, `CANNOT_MANAGE_OWN_REWARD_SETTLEMENT`, reviewer ≠ assignee → 403, `isLate`/`submittedAt`/sort, LedgerEntry `REWARD` khi `confirm-received`.

### Chờ trả lời mới làm

6. Bỏ hẳn N+1 khi **B5/Đ12** deploy — sửa luôn cả L4 lẫn phần lớn L3. Chờ BE báo chọn hướng embed hay bulk.
7. Khi có `ASSIGNMENT_NOT_STARTABLE` (Đ11): **bỏ hẳn bước tự đoán trạng thái trước khi gọi** ở
   [`startAssignment`](lib/providers/task_provider.dart:1086) — gọi thẳng `PATCH .../start`, BE trả
   400 kèm mã ổn định thì dịch sang tiếng Việt. Vừa bớt 1 request mỗi lần bấm, vừa hết hẳn ca "FE và
   BE bất đồng về status".
8. Giữ hay gỡ `isAssignmentNotStarted()` theo **C4**.
9. Nếu **A2** cho ra `FAMILY_MEMBER` (GT-3): truy lỗ hổng điều hướng cho phép vai này vào
   `/manager/tasks`, và rà chỗ đồng bộ `familyRole` giữa BE và `AuthProvider`.

**Chưa đụng vào**: [`_myMemberId`](lib/screens/parent/task_management_screen.dart:525) đang so
`m.id == userId` — trộn hai không gian định danh `familyMember.id` và `user.id`. Chưa thấy bằng
chứng nó gây lỗi trong 2 ảnh này, nhưng nó chi phối toàn bộ việc nhận diện "việc của tôi". Phụ
thuộc **A3**: nếu A3 = "sai" thì đây là nghi phạm số một, xử lý trước tất cả.
