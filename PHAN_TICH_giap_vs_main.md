# Phân tích khác biệt: nhánh local `giap` ⟷ `origin/main`

**Repo:** `16-Doffy/SEP-Family-Care-Mobile`
**Ngày phân tích:** 2026-07-10
**Local branch:** `giap` (HEAD = `2d747da`)
**Remote đối chiếu:** `origin/main` (HEAD = `39e5c70`, đã `git fetch` mới nhất)

---

## 0. Tóm tắt điều hành (đọc cái này trước)

| Chỉ số | Giá trị |
|---|---|
| Điểm rẽ nhánh (merge-base) | `aba3805` — chính là **HEAD~1 của giap** |
| Commit **main có mà giap chưa có** | **46 commit** |
| Commit **giap có mà main chưa có** | **1 commit** (`2d747da`) |
| File main sửa/thêm mà giap chưa có | **49 file** (`+2287 / −220` dòng) |
| File có nguy cơ đụng độ (cả 2 nhánh cùng sửa) | **5 file** |
| Đụng độ *văn bản* khi merge | **0** (git tự merge sạch) |
| Đụng độ *ngữ nghĩa* nghiêm trọng | **1** — luồng verify-email (xem §4) |

**Kết luận nhanh:**

1. `origin/main` đi trước giap rất xa (46 commit), gồm nhiều fix API thật + tính năng mới → **nên kéo về**.
2. `git merge` sẽ **merge sạch về mặt văn bản**, NHƯNG sẽ **âm thầm phá vỡ** fix verify-email của bạn (`2d747da`) vì giap và main đi **ngược hướng nhau** ở luồng này. Đây là bẫy "clean merge – broken behavior". Phải xử lý tay 5–6 file (§4).
3. 16 file đang "modified" trong working tree **KHÔNG phải sửa nội dung** — chỉ là **đổi CRLF ↔ LF** (Windows). Cần dọn trước khi merge (§6).

---

## 1. Topology hai nhánh

```
aba3805  (merge-base = HEAD~1 của giap)
   │  "feat: verify-email OTP, wire toàn bộ Finance API còn lại, và Reward Management mới"
   │
   ├─────────────► giap (local, HEAD)
   │                 2d747da  "fix: bỏ chặn cứng verify-email, sửa 2 bug qua test tay"
   │
   └─────────────► origin/main (HEAD = 39e5c70)
                     46 commit mới (fix API thật, deep-link, UI kit dùng chung, Windows desktop...)
```

Vì `aba3805` là **tổ tiên của cả hai**, nên thực chất:

- Giáp tách ra từ `aba3805` và **chỉ thêm 1 commit** (`2d747da`).
- `main` cũng đi từ `aba3805` nhưng thêm **46 commit**.
- => Hai nhánh **đã phân kỳ thật sự** (diverged), không phải fast-forward. Cần `merge` hoặc `rebase`.

---

## 2. 46 commit của `main` mà giap chưa có — nhóm theo chủ đề

### 2.1. Fix API thật / khớp response BE (ưu tiên cao — nên kéo)
| Commit | Nội dung |
|---|---|
| `587495a` | Ví member hiện "Chưa khai báo" oan + lịch sử trống gây hiểu lầm |
| `9c42d02` | Xem lại bài nộp sau khi duyệt — nút "Xem bài nộp" cho assignment APPROVED/REJECTED |
| `5794db0` | Manager duyệt task không thấy ảnh minh chứng (list submissions không kèm proofs) |
| `3bfa784` | Upload ảnh minh chứng bị 400 "Định dạng file không được hỗ trợ" |
| `05f3e64` | Member không bấm được task — BE trả `ASSIGNED`, UI check `PENDING` |
| `409d73a` | Parse subscription plans đúng response thật của BE |
| `19a27c4` | Fix finance dedupe + refresh swagger |
| `6a1e8d1` | Validate & sửa field names task + finance theo swagger |
| `7d28c60` | Sửa reward settlement flow theo ERD |
| `932e013` | Fix màn Subscription + lỗi settlement |
| `8208cd2` | Restore finance allocation UX + nhãn tiếng Việt |
| `348254e` | Fix finance UX + task proof review |

### 2.2. Tính năng mới (nên kéo)
| Commit | Nội dung |
|---|---|
| `39e5c70` | **Deep link kết quả thanh toán Stripe** + giữ deep link qua cold-start |
| `6844267` | Fix token mời dính vĩnh viễn (mọi lần login bị đẩy về màn Tham gia) |
| `6f34d44` | Thêm mục "Duyệt yêu cầu tham gia" vào menu Tôi của Manager |
| `f8f7603` | Link mời thành viên hoạt động thật — deep link + lời nhắn kèm mã |
| `38718fd` | Fix nút back màn Tham gia gia đình chết khi mở qua deep link |
| `060b263` | Wire email verification (UC10) + invitation reject APIs |
| `77b5f77` | Wire remaining detail + subscription endpoints |
| `f00853b` | Thêm `fetchAlertDetail` vào `SosProvider` |
| `a0a1bea` | Wire invitation approval flow + task calendar |
| `50ab4bf` | Form validation, **shared UI kit**, task category wiring |

### 2.3. UI kit / theme dùng chung (nên kéo — nền tảng cho màn mới)
| Commit | Nội dung |
|---|---|
| `23980fa` | **Merge NDuy vào giap** — port UI kit + fix từ NDuy (giữ kiến trúc giap) |
| `ba88fb3` | Auth escape routes, goal parse/contribution UI, money input formatting |
| `5dcada1` | Sửa dấu tiếng Việt toàn bộ màn hình + cập nhật handoff docs |

### 2.4. Hạ tầng / dọn dẹp (chọn lọc)
| Commit | Nội dung | Khuyến nghị |
|---|---|---|
| `4dabe46` | Regenerate Windows plugin registrant | Kéo (đi kèm folder `windows/`) |
| `8946e35`…`261df6c` (nhóm "done api …") | Loạt commit wire API tasks/finance/family/subscription trước đó | Đã nằm trong lịch sử main — kéo nguyên |
| `3df0cf7` `781ede8` `a0a1bea` | Docs handoff, ERD | Kéo (chỉ là tài liệu) |

> ⚠️ Các commit cũ dạng `261..cccc..1fc98` dùng IP cũ `103.110.84.66` trong commit message, nhưng nhánh main hiện tại **đã** chuyển sang domain HTTPS ở các commit sau — kiểm tra `apiBaseUrl` sau merge (§5, `api_client.dart`).

---

## 3. Khác biệt CHI TIẾT từng file (`giap HEAD` → `origin/main`)

Ký hiệu: **[MỚI]** = file main có, giap chưa có · **[SỬA]** = cả 2 có, main sửa · **[XÓA]** = main bỏ file giap đang có.

### 3.1. `lib/services/` — nên kéo nguyên
| File | Loại | Chi tiết |
|---|---|---|
| `lib/services/api_client.dart` | [SỬA] | Thêm `_guessMimeType()` để **đoán Content-Type từ đuôi file** khi upload minh chứng. BE trả 400 "Định dạng file không được hỗ trợ" nếu gửi `application/octet-stream`. **Fix quan trọng, kéo về.** |

### 3.2. `lib/providers/` — nên kéo nguyên
| File | Loại | Chi tiết |
|---|---|---|
| `finance_provider.dart` | [SỬA] | `FinancialGoal.fromJson` **bóc lớp `{goal:{}, progress:{}}`** khi `includeProgress=true`. Đọc phẳng ra tên rỗng/0đ. **Fix bug live, kéo.** |
| `task_provider.dart` | [SỬA] | (1) Thêm nhãn status `ASSIGNED → '⚪ Chờ làm'`. (2) `fetchLatestSubmission()` **gọi thêm endpoint detail** để lấy mảng `proofs` (list submissions chỉ trả `proofCount`). **Khớp ghi chú KB của bạn, kéo.** |
| `auth_provider.dart` | [SỬA] ⚠️ | Xem §4 — **có xung đột ngữ nghĩa với `2d747da`**. Main thêm `clearPendingInviteToken()` lúc logout (tốt), nhưng nhánh check 403 verify khác hướng bạn. |

### 3.3. `lib/navigation/app_router.dart` — ⚠️ cần review tay (§4)
| Loại | Chi tiết |
|---|---|
| [SỬA] | Main thêm: (1) import `payment_result_screen`; (2) cơ chế **`pendingDeepLink`** giữ deep link qua cold-start rồi replay sau khi restore session; (3) **rule ép verify:** `if (pendingEmailVerification && !hasFamily) return '/verify-email'`. **Rule (3) ngược với `2d747da`** (bạn đã cố tình bỏ chặn cứng). |

### 3.4. `lib/screens/` — phần lớn kéo được, riêng nhóm verify cần tay
| File | Loại | Chi tiết | Khuyến nghị |
|---|---|---|---|
| `parent/task_management_screen.dart` | [SỬA] | Thêm nút **"Xem bài nộp"** (read-only) cho task đã APPROVED/REJECTED, hiện `reviewNote` cũ | ✅ Kéo |
| `child/child_tasks_screen.dart` | [SỬA] | Filter "Chờ làm" nhận thêm status **`ASSIGNED`**; nút làm task hiện khi `ASSIGNED\|PENDING` | ✅ Kéo |
| `child/child_wallet_screen.dart` | [SỬA] | (1) parse số dạng **string** (`"3000000"`) khỏi crash "Chưa khai báo" oan; (2) member bị 403 sổ quỹ chung → đổi text hướng dẫn thay vì "chưa có giao dịch" | ✅ Kéo |
| `parent/subscription_screen.dart` | [SỬA] | (1) `annualPrice`/`storageLimit` là **string** → `double.tryParse`; (2) map key `featureAccess` mới (aiEnabled, advancedFinance…); (3) hiển thị **giá/năm** thay vì /tháng; (4) thêm gói **GOLD** | ✅ Kéo |
| `parent/invite_member_screen.dart` | [SỬA] | Link mời đổi sang **deep link `familycare://app/join?token=`** + lời nhắn kèm mã (bỏ URL `api.../join` trả 404) | ✅ Kéo |
| `auth/family_setup_screen.dart` | [SỬA] ⚠️ | Main **BỎ** dialog "Xác thực ngay / Để sau", để router tự ép sang verify | ⚠️ §4 |
| `auth/verify_email_screen.dart` | [SỬA] ⚠️ | Main **BỎ** nút back + "Để sau" (không cho thoát màn verify) | ⚠️ §4 |
| `auth/join_family_screen.dart` | [SỬA] ⚠️ | Cả 2 nhánh cùng sửa — cần review | ⚠️ §4 |
| `shared/profile_screen.dart` | [SỬA] ⚠️ | Main **BỎ** tile "📧 Xác thực email", **THÊM** tile "🙋 Duyệt yêu cầu tham gia" | ⚠️ §4 |
| `shared/payment_result_screen.dart` | **[MỚI]** | Màn kết quả thanh toán Stripe (success/failed) — đi kèm deep-link | ✅ Kéo |

### 3.5. `lib/widgets/` + `lib/theme/` + `lib/utils/` — [MỚI], nền tảng UI kit
| File | Loại | Chi tiết |
|---|---|---|
| `theme/app_theme.dart` | [SỬA] | **ThemeData chung** — `inputDecorationTheme`, `elevatedButtonTheme`, dialog/sheet style đồng bộ toàn app |
| `widgets/app_input.dart` | **[MỚI]** | Ô nhập chuẩn (215 dòng) — dùng chung |
| `widgets/empty_state.dart` | **[MỚI]** | Empty-state chuẩn (emoji + tiêu đề + mô tả) |
| `widgets/money_input.dart` | **[MỚI]** | `ThousandsSeparatorInputFormatter` (1234567 → 1.234.567) |
| `utils/validators.dart` | **[MỚI]** | Bộ `Validators` (email/phone/… trả message lỗi) |
| `widgets/ring_chart.dart` | [SỬA] | Thay đổi rất nhỏ (2 dòng) |

> ⚠️ **Phụ thuộc chéo:** `subscription_screen`, `login_screen`, `family_setup`… ở main **có thể đã dùng** `app_input.dart` / `validators.dart` / `AppTheme`. Nếu bạn cherry-pick lẻ mà bỏ nhóm UI kit này → **lỗi biên dịch**. Kéo cả cụm hoặc merge nguyên khối.

### 3.6. Cấu hình / hạ tầng
| File | Loại | Chi tiết | Khuyến nghị |
|---|---|---|---|
| `android/app/src/main/AndroidManifest.xml` | [SỬA] | Thêm `flutter_deeplinking_enabled` + `intent-filter` cho `familycare://app/join` | ✅ Kéo (cần cho deep link mời) |
| `android/gradle.properties` | [SỬA] | +1 dòng | ✅ Kéo |
| `windows/**` (18 file) | **[MỚI]** | Toàn bộ **Windows desktop runner** + plugin registrant | ⚪ Tùy — chỉ cần nếu build Windows. Vô hại nếu kéo. |
| `.vscode/launch.json` | **[MỚI]** | Cấu hình debug | ⚪ Tùy chọn |
| `devtools_options.yaml`, `family-care-api.json` | **[MỚI]** | Devtools config + snapshot OpenAPI của BE | ⚪ Tùy chọn (tiện tra cứu) |
| `test/app_router_redirect_test.dart` | [SỬA] | Cập nhật test theo logic redirect mới của main | ⚠️ Kéo kèm §4 (test này phản ánh hướng verify của main) |
| `update_skill.ps1` | **[XÓA]** | Main xóa file này (giap còn giữ) | ⚪ Xác nhận có cần giữ không |

### 3.7. Tài liệu
| File | Loại | Chi tiết |
|---|---|---|
| `AI_HANDOFF_LATEST.md` | **[MỚI]** | Handoff 313 dòng — ngữ cảnh mới nhất giữa các phiên |
| `README.md`, `API_DOCS.md` | [SỬA] | Cả 2 nhánh cùng chỉnh (giap sửa ở `2d747da`, main sửa riêng). Đụng nhẹ, dễ hòa. |

---

## 4. ⚠️ XUNG ĐỘT NGỮ NGHĨA: luồng verify-email (QUAN TRỌNG NHẤT)

Đây là điểm nguy hiểm nhất. `git merge` báo **0 xung đột văn bản**, nhưng đó là vì giap và main sửa **các dòng khác nhau** → git ghép cả hai lại → hành vi **mâu thuẫn**.

**Hai nhánh đi NGƯỢC hướng nhau:**

| | Nhánh `giap` (`2d747da` — bạn) | Nhánh `origin/main` |
|---|---|---|
| Triết lý | Verify email **KHÔNG bắt buộc**, chỉ chặn đúng lúc tạo family | Verify email **BẮT BUỘC** trước khi vào `/family-setup` |
| `app_router` | Bỏ rule "giam" ở `/verify-email` | **Thêm** `if (pendingEmailVerification && !hasFamily) return '/verify-email'` |
| `verify_email_screen` | **Thêm** nút back + "Để sau" (thoát tự do) | **Không có** back/skip (khóa lại) |
| `family_setup_screen` | **Thêm** dialog "Xác thực ngay / Để sau" | **Bỏ** dialog, để router tự ép |
| `profile_screen` | **Thêm** tile "📧 Xác thực email" (lối vào lại) | **Bỏ** tile đó, thay bằng "🙋 Duyệt yêu cầu tham gia" |
| `auth_provider` (createFamily 403) | `if (e.statusCode == 403)` — **tin thẳng status** vì BE trả message tiếng Việt không chứa "verif" | `if (e.statusCode == 403 && message.contains('verif'))` — **check message** (chính là bug bạn đã sửa!) |

**Rủi ro nếu merge mù:**
- Router main **ép** người dùng chưa verify về `/verify-email`, nhưng `verify_email_screen` (nếu giữ bản giap) lại có nút "Để sau" → thoát ra rồi **bị đá ngược lại ngay** → kẹt vòng lặp.
- Hoặc mất luôn tile "Xác thực email" trong Profile (main bỏ) → user lỡ bỏ qua không có đường quay lại.
- `auth_provider`: nếu bản main thắng ở dòng check 403 → **tái sinh đúng con bug** bạn đã fix ở `2d747da` (dialog xác thực không hiện với message tiếng Việt).

> 🔧 **Bắt buộc:** 6 file này phải **review & quyết định hướng sản phẩm** trước khi commit merge:
> `app_router.dart`, `auth_provider.dart`, `family_setup_screen.dart`, `verify_email_screen.dart`, `profile_screen.dart`, `join_family_screen.dart` (+ `test/app_router_redirect_test.dart`).
>
> **Câu hỏi cần chốt với team (Nhật/Nghĩa):** verify-email là **bắt buộc** (hướng main) hay **tùy chọn** (hướng bạn)? BE thực tế đang 403 ở `POST /families` — hướng main khớp ràng buộc BE hơn, nhưng cần giữ **1 lối quay lại** verify (tile Profile) và **bỏ** nút "Để sau" cho nhất quán.

---

## 5. Điểm cần verify sau merge

- **`api_client.dart` → `apiBaseUrl`**: đảm bảo là `https://api.familycare-digital.com/api/v1`, KHÔNG phải IP cũ `103.110.84.66`. `[VERIFY]`
- **Cụm UI kit** (`app_input`, `validators`, `money_input`, `empty_state`, `AppTheme`): chạy `flutter analyze` sau merge để bắt import thiếu. `[VERIFY]`
- **Deep link mời**: `familycare://app/join?token=` cần `intent-filter` (AndroidManifest) — kéo kèm nhau. Test mở link khi app đã tắt hẳn (cold-start). `[VERIFY]`
- **Test**: `flutter test test/app_router_redirect_test.dart` sẽ phản ánh hướng verify đã chọn ở §4. `[VERIFY]`

---

## 6. Chiến lược kéo về — khuyến nghị theo thứ tự

### Bước 0 — Dọn "nhiễu" CRLF trước (bắt buộc)
16 file đang "modified" **không đổi nội dung**, chỉ đổi CRLF↔LF (đã kiểm chứng: diff bỏ whitespace = rỗng). Nếu để nguyên sẽ nhiễu khi merge.

```bash
# Cấu hình để Git tự chuẩn hóa line-ending trên Windows
git config core.autocrlf true

# Bỏ các thay đổi CRLF giả (KHÔNG mất code thật)
git checkout -- .

# .claude/ đang untracked — thêm vào .gitignore nếu không muốn commit
echo ".claude/" >> .gitignore
```

### Bước 1 — Backup nhánh hiện tại
```bash
git branch giap-backup-20260710
```

### Bước 2 — Chọn 1 trong 2 hướng

**Hướng A (khuyến nghị): merge có kiểm soát**
```bash
git fetch origin
git merge origin/main --no-commit --no-ff
# → Git merge sạch về văn bản. DỪNG LẠI, chưa commit.
# → Mở 6 file ở §4, quyết định hướng verify-email, sửa tay cho nhất quán.
flutter pub get && flutter analyze && flutter test
git commit        # chỉ commit khi analyze + test xanh
```

**Hướng B: rebase 1 commit của bạn lên main** (lịch sử phẳng hơn, nhưng phải xử lý xung đột verify ngay trong lúc rebase)
```bash
git rebase origin/main
# Giải quyết luồng verify-email khi git dừng, rồi:
git rebase --continue
```

> Ưu tiên **Hướng A** vì bạn được xem toàn cảnh 46 commit của main trước khi quyết định, thay vì phải quyết ngay giữa rebase.

### Bước 3 — Nếu chỉ muốn lấy fix quan trọng, bỏ phần verify (cherry-pick chọn lọc)
Chỉ dùng khi CHƯA muốn động vào luồng verify:
```bash
# Nhưng LƯU Ý: nhiều màn hình main đã phụ thuộc UI kit + theme mới.
# Cherry-pick lẻ dễ vỡ biên dịch → phải kéo kèm cụm 50ab4bf/ba88fb3/23980fa.
git cherry-pick 3bfa784 5794db0 9c42d02 05f3e64 587495a 409d73a
```

---

## 7. Bảng quyết định nhanh "kéo hay không"

| Nhóm file | Kéo? | Lý do |
|---|---|---|
| `api_client`, `finance_provider`, `task_provider` | ✅ Kéo nguyên | Fix API thật, khớp BE |
| Screens task/wallet/subscription/invite | ✅ Kéo nguyên | Fix live + tính năng thật |
| UI kit (`app_input`, `validators`, `money_input`, `empty_state`, `app_theme`) | ✅ Kéo cả cụm | Nền tảng, tránh vỡ import |
| `payment_result_screen` + deep link (manifest, router phần deep-link) | ✅ Kéo | Tính năng Stripe cold-start |
| **Luồng verify-email** (6 file §4) | ⚠️ Review tay | Ngược hướng `2d747da` — quyết định sản phẩm |
| `windows/**`, `.vscode`, `devtools_options` | ⚪ Tùy chọn | Vô hại; chỉ cần nếu build Windows / muốn config |
| `update_skill.ps1` (main xóa) | ⚪ Xác nhận | Kiểm tra bạn còn cần script này không |

---

*File này chỉ mô tả & đề xuất — chưa thực hiện thay đổi nào lên repo. Sau khi chốt hướng verify-email (§4), có thể tiến hành theo §6.*
