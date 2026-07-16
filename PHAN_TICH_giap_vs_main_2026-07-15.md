# Phân tích khác biệt `giap` ↔ `origin/main` — 2026-07-15

> Đối chiếu nhánh làm việc local **`giap`** với **`origin/main`** (`https://github.com/16-Doffy/SEP-Family-Care-Mobile`).
> Thời điểm fetch: 2026-07-15. `origin/main` HEAD = `93612a9`. `giap` HEAD = `cb050e9`.

---

> ## ✅ ĐÃ THỰC HIỆN (cập nhật 2026-07-16)
> Kế hoạch §5 đã chạy xong: **FF `giap` → `93612a9`** (backup `giap-backup-before-ff-20260715`), tái hoà WIP theo A/B/C — giữ poll/badge/manifest, ghép Album+badge ở `child_home`, **làm lại QR trên mã 8 ký tự** cho invite/join. Thêm map fix + SOS timeline + Home status. Hiện **9 commit local trên `giap`, chưa push**. `flutter test` 55/55 pass. Doc này giữ làm lịch sử phân tích trước-merge.

---

## 0. TL;DR (đọc nhanh)

| Chỉ số | Giá trị |
|---|---|
| Quan hệ 2 nhánh | `giap` là **tổ tiên trực tiếp** của `main` (`merge-base = giap HEAD = cb050e9`) |
| `giap` đi trước `main` | **0 commit** |
| `main` đi trước `giap` | **11 commit** |
| File thay đổi (đã commit) | **31 file**, +1867 / −1804 dòng |
| Có thể fast-forward? | **CÓ** — nếu bỏ qua working tree, `giap` FF thẳng lên `main` không đụng độ commit |
| ⚠️ Vướng | **8 file đang sửa dở, CHƯA commit** trên working tree — trong đó **3 file đụng độ trực tiếp** với thay đổi của `main` |

**Kết luận 1 câu:** Về mặt commit, kéo `main` về là **fast-forward sạch**. Rủi ro thật nằm ở **8 file local chưa commit** (feature QR mời + polling + badge chuông) — đặc biệt **feature QR đang xây trên luồng mời cũ (`?token=`) mà `main` đã xoá bỏ hoàn toàn** để chuyển sang **mã mời 8 ký tự + join-request**. Cần xử lý phần local trước khi merge, nếu không sẽ mất công hoặc conflict.

---

## 1. Topology 2 nhánh

```
cb050e9 (giap, HEAD)  ← merge-base
   │
   └── 3f53424 ── 0c22014 ── 6d65ee3 ── 183c508 ── ac82b46 ── 359d12b
                ── 627b2c4 ── fc59c69 ── 3c5f9cb ── 1fc2eea ── 93612a9 (origin/main)
```

Vì merge-base **bằng đúng** HEAD của `giap`, nhánh `giap` không có commit riêng nào. Toàn bộ khác biệt commit = 11 commit `main` ship thêm sau khi `giap` tách ra. **Không có nguy cơ conflict ở tầng commit** — chỉ FF.

> Nhánh local phụ đang có: `giap-backup-20260710`, `giap-backup-before-ff-20260711` (đã có thói quen backup trước khi FF — tốt, giữ nguyên).

---

## 2. 11 commit `main` ship thêm (nhóm theo chủ đề)

| # | Hash | Commit | Nhóm |
|---|---|---|---|
| 1 | `3f53424` | feat: nút Tin an toàn nhanh trong chat (SOS_QUICK_MESSAGE) + CTA Hạ gói ở subscription | Chat / Subscription |
| 2 | `0c22014` | merge: Album API thật + Finance pagination/monthly-finance vào NDuy | Merge lớn |
| 3 | `6d65ee3` | feat: 4 EP BE mới — xem tài chính member (UC gap #5) + album moderation queue | Finance / Album |
| 4 | `183c508` | fix: đổi tab member 'Ví' → 'Tài chính' | Navigation |
| 5 | `ac82b46` | feat: mở Album cho Deputy/Member — route phẳng `/album` | Album / Navigation |
| 6 | `359d12b` | docs: planCode → FREE\|MONTHLY\|YEARLY | Docs |
| 7 | `627b2c4` | fix: subscription không nháy FREE 2–3s khi đang tải | Subscription |
| 8 | `fc59c69` | fix: tách `userType` (SYSTEM_ADMIN) khỏi familyRole | Auth / Model |
| 9 | `3c5f9cb` | **feat: migrate to invite code + manual album tagging** | **Invite (BIG) / Album** |
| 10 | `1fc2eea` | chore: clean invite & album async handling | Cleanup |
| 11 | `93612a9` | feat: rename wallet → ledger record + SOS inline map & navigation | SOS / Rename |

Hai commit "nặng" nhất và đáng chú ý nhất với công việc FE Mobile:
- **`3c5f9cb`** — thay toàn bộ luồng mời `invitations` (email + token) bằng **mã mời tái sử dụng + join-request** (khớp đúng tài liệu tích hợp "vào gia đình bằng mã mời" mà team đã chốt).
- **`0c22014`** — merge Album API thật + Finance monthly-finance (nền cho commit `6d65ee3`).

---

## 3. Phân tích từng file (31 file, gom theo module)

Ký hiệu: **[KÉO]** nên lấy về · **[KÉO – lưu ý]** lấy về nhưng đụng local · **[TỰ ĐỘNG]** theo cùng khi FF, không cần thao tác riêng.

### 3.1. Module MỜI GIA ĐÌNH — thay đổi lớn nhất, đụng độ local

| File | Δ | Nội dung `main` | Đề xuất |
|---|---|---|---|
| `lib/providers/invitation_provider.dart` | +242/− | **Viết lại hoàn toàn.** Bỏ `invitations`/token; thêm `fetchInviteCode()`, `regenerateInviteCode()`, `previewInviteCode(code)`, `requestJoinByCode(code)`, `fetchJoinRequests()`, `approveJoinRequest()`, `rejectJoinRequest()`, `fetchMyJoinRequests()`, `cancelMyJoinRequest()` + class `JoinRequest`. | **[KÉO]** Bắt buộc — đây là contract mới BE đang chạy. |
| `lib/screens/auth/join_family_screen.dart` | +483/− | Viết lại: nhập mã 8 ký tự → `GET /invite-codes/{code}` preview → gửi join-request → poll `GET /me/join-requests`. | **[KÉO – lưu ý]** ⚠️ **Đụng file local đang sửa** (xem §4). |
| `lib/screens/parent/invite_member_screen.dart` | +520/− | Viết lại thành màn "mã mời tái sử dụng": hiện mã 8 ký tự + nút **Đổi mã** (`regenerate`, có dialog xác nhận). **Không còn QR, không còn token.** | **[KÉO – lưu ý]** ⚠️ **Đụng file local đang sửa** (xem §4). |
| `lib/screens/parent/invitation_requests_screen.dart` | +278/− | Viết lại: danh sách join-request PENDING → duyệt/từ chối bằng `approve`/`reject`. | **[KÉO]** |
| `lib/screens/auth/family_setup_screen.dart` | +69/−540 | Gỡ sạch phần tạo lời mời email/token cũ khỏi luồng setup (giảm ~540 dòng). | **[KÉO]** |

> Nhóm này **là lý do chính** vì sao không thể merge cẩu thả: `main` xoá bỏ luồng `?token=`, còn feature QR local lại xây trên chính luồng đó.

### 3.2. Module ALBUM — manual tagging + moderation + mở cho Deputy/Member

| File | Δ | Nội dung `main` | Đề xuất |
|---|---|---|---|
| `lib/models/album_media.dart` | +44/− | Thêm field cho manual tagging (tags, moderationStatus, riskScore, permissions.canRemove…). | **[KÉO]** |
| `lib/providers/album_provider.dart` | +30/− | Thêm `fetchModerationQueue()`, thao tác tag/moderation thủ công (`MARK_SAFE`/`KEEP_FLAGGED`). | **[KÉO]** |
| `lib/screens/shared/album_screen.dart` | +299/− | UI tag thủ công + sheet 🛡️ hàng đợi kiểm duyệt (riskScore + tóm tắt AI, duyệt nhanh). | **[KÉO]** |
| `lib/screens/shared/profile_screen.dart` | +6 | Tile "Album gia đình" cho Deputy & Member (Manager đã có tab). | **[KÉO]** |
| `lib/screens/child/child_home_screen.dart` | +22 | Shortcut 🖼️ Album ở Trang chủ Member. | **[KÉO – lưu ý]** ⚠️ **Đụng file local đang sửa** (badge chuông — xem §4). |

> Album trên `main` đi theo **manual tagging, CHƯA bật Face AI** — đúng như flow team mô tả (`/face-*` cố ý không gọi). Nhất quán với `API_MOBILE_AUDIT_2026-07-15.md`.

### 3.3. Module FINANCE — monthly summary + xem tài chính member

| File | Δ | Nội dung `main` | Đề xuất |
|---|---|---|---|
| `lib/providers/finance_provider.dart` | +116 | Thêm `fetchMonthlySummaryMe()`, `fetchMemberMonthlySummary()`, `fetchMemberMonthlyFinance()` + model `MonthlySummary` (parse phòng thủ — EP mới trả **number thật**, khác EP finance cũ trả string). | **[KÉO]** |
| `lib/screens/parent/member_finance_screen.dart` | **MỚI +332** | Màn mới (route `/manager/member-finance`): Manager/Deputy xem tài chính tháng của member; field private BE trả null → hiện "Riêng tư"; gate `canManageFinance`. | **[KÉO]** |
| `lib/screens/parent/member_list_screen.dart` | +30 | Thêm entry mở màn member-finance từ sheet + chỉnh nhỏ theo luồng mời mới. | **[KÉO]** |
| `lib/screens/child/child_wallet_screen.dart` | +2/−2 | Đổi nhãn theo rename ledger. | **[TỰ ĐỘNG]** |
| `lib/screens/parent/wallet_screen.dart` | +2/−2 | Đổi nhãn theo rename ledger. | **[TỰ ĐỘNG]** |

### 3.4. Module SUBSCRIPTION

| File | Δ | Nội dung `main` | Đề xuất |
|---|---|---|---|
| `lib/screens/parent/subscription_screen.dart` | +105/− | (`3f53424`) thêm `priceValue` → gói rẻ hơn hiện "Hạ xuống {tên}" + dialog xác nhận mất quyền lợi. (`627b2c4`) `_currentPlan` nullable = đang tải → hiện spinner, khoá checkout khi chưa biết gói → **hết nháy FREE 2–3s**. | **[KÉO]** |

### 3.5. Module CHAT / SOS

| File | Δ | Nội dung `main` | Đề xuất |
|---|---|---|---|
| `lib/screens/shared/chat_screen.dart` | +93 | Nút khiên → sheet 4 tin mẫu, gửi `messageType=SOS_QUICK_MESSAGE`; bubble cam viền `F59E0B` nhãn "TIN AN TOÀN". | **[KÉO]** |
| `lib/providers/chat_provider.dart` | +7 | Hỗ trợ gửi/parse type `SOS_QUICK_MESSAGE`. | **[KÉO]** |
| `lib/screens/shared/sos_screen.dart` | +162 | Bản đồ inline trong màn SOS + điều hướng; dùng location của SOS alert (`.../location/current`, `.../locations/batch`). | **[KÉO]** |
| `lib/screens/shared/family_map_screen.dart` | +11 | Tinh chỉnh theo location SOS. | **[KÉO]** |

### 3.6. Module AUTH / MODEL / ROUTER (nền tảng)

| File | Δ | Nội dung `main` | Đề xuất |
|---|---|---|---|
| `lib/models/user.dart` | +53/− | (`fc59c69`) exact-match `FAMILY_MANAGER`/`DEPUTY_MEMBER`/`FAMILY_MEMBER` thay vì `contains('ADMIN')` (trước match nhầm `SYSTEM_ADMIN` → gán nhầm `manager`); thêm `userType` (NORMAL_USER\|SYSTEM_ADMIN) + `isSystemAdmin` + `familyRoleString`. (`93612a9`) rename ledger. | **[KÉO]** — đây là **fix đúng đắn quan trọng**, ảnh hưởng phân quyền toàn app. |
| `lib/providers/auth_provider.dart` | +27/− | Sửa hardcode `'MANAGER'` → `'FAMILY_MANAGER'`; `role.name.toUpperCase()` → `familyRoleString` (token rotation); rename ledger. | **[KÉO]** |
| `lib/navigation/app_router.dart` | +57/− | Route phẳng `/album` (mọi role), route `/manager/member-finance`, redirect luồng mã mời, đổi tab member `Ví`→`Tài chính`, rename ledger. | **[KÉO]** |
| `lib/providers/task_provider.dart` | +1 | Chỉnh nhỏ. | **[TỰ ĐỘNG]** |
| `lib/screens/parent/task_management_screen.dart` | +22/− | Theo rename ledger + chỉnh nhỏ task. | **[KÉO]** |
| `lib/screens/shared/notifications_screen.dart` | +2 | Chỉnh nhỏ. | **[TỰ ĐỘNG]** |

### 3.7. TEST + DOCS

| File | Δ | Nội dung | Đề xuất |
|---|---|---|---|
| `test/app_router_redirect_test.dart` | **MỚI +21** | Test redirect router (luồng mời/role). | **[KÉO]** — có test là tốt, chạy `flutter test` sau merge. |
| `test/auth_provider_test.dart` | **MỚI +27** | Test parse role/auth. | **[KÉO]** |
| `API_MOBILE_AUDIT_2026-07-15.md` | **MỚI +40** | Audit API 15/07 vs Swagger prod: liệt kê EP đã nối + danh sách "Cần báo Backend" (location, PATCH /auth/me, calendar, AI, FCM…). | **[KÉO]** — tài liệu tham chiếu quan trọng, xem §6. |
| `AI_HANDOFF_LATEST.md` | +9 | Cập nhật handoff theo các commit trên. | **[TỰ ĐỘNG]** |
| `API_DOCS.md` | +19/− | Cập nhật Chat/Subscription/Album/monthly-summary + planCode. | **[TỰ ĐỘNG]** |

---

## 4. ⚠️ XUNG ĐỘT VỚI CODE LOCAL CHƯA COMMIT (phần rủi ro nhất)

Working tree `giap` đang có **8 file sửa dở, chưa commit** — một feature-set "QR mời + polling + badge chuông":

```
 android/app/src/main/AndroidManifest.xml      |  3 +   (camera permission)
 lib/navigation/family_shell.dart              | 44 ++   (polling SOS+notif 15s)
 lib/screens/auth/join_family_screen.dart      | 172 ++  ⚠️ ĐỤNG main
 lib/screens/child/child_home_screen.dart      | 31 ++   ⚠️ ĐỤNG main
 lib/screens/parent/home_dashboard_screen.dart | 31 ++
 lib/screens/parent/invite_member_screen.dart  | 59 ++   ⚠️ ĐỤNG main
 pubspec.lock / pubspec.yaml                   | +qr_flutter ^4.1.0, mobile_scanner ^7.2.0
```

### 4.1. Vấn đề nghiêm trọng: feature QR xây trên luồng mời ĐÃ BỊ XOÁ

Feature QR local hoạt động như sau:
- `invite_member_screen.dart` (local): thay QR placeholder bằng **QR thật** encode deep link `familycare://app/join?token=<token>`.
- `join_family_screen.dart` (local): thêm `_scanQr()` (mobile_scanner) + `_extractToken()` tách token từ URL/deep link/clipboard → lookup.

Nhưng `main` (`3c5f9cb`) đã:
- Xoá luồng `?token=` — `invitation_provider` **không còn** lookup theo token, chỉ còn `previewInviteCode(code)` theo **mã 8 ký tự**.
- `invite_member_screen.dart` bản `main` chỉ hiện mã 8 ký tự + nút Đổi mã, **không có QR**.

➡️ **Hệ quả:** nếu FF thẳng lên `main`, 3 file local (`join_family`, `invite_member`, và một phần logic token) sẽ **conflict**, và kể cả giải conflict xong thì **feature QR vẫn sai bản chất** vì nó encode/parse token — thứ BE không còn hiểu.

### 4.2. Hai file còn lại: đụng nhưng GHÉP ĐƯỢC

| File | Local làm gì | `main` làm gì | Xử lý |
|---|---|---|---|
| `child_home_screen.dart` | Thêm **badge chuông** unread count (99+), viền trắng | Thêm **shortcut Album** | Khác vùng code → ghép cả hai được, chỉ conflict text nhẹ. |
| `home_dashboard_screen.dart` | Thêm badge chuông unread count | *(main không đụng file này)* | Không conflict — giữ nguyên local. |

### 4.3. Phần local KHÔNG đụng `main` (giữ nguyên, an toàn)

- `family_shell.dart` — polling 15s SOS + notification, dừng khi app xuống nền, fetch lại khi resume. `main` không đụng file này. **Giữ.** (Khớp ghi chú audit: BE chưa có push/WebSocket → phải poll.)
- `AndroidManifest.xml` — camera permission (feature QR cần).

---

## 5. ĐỀ XUẤT KÉO VỀ — chiến lược cụ thể

### Bước 0 — Backup (bắt buộc)
```bash
git branch giap-backup-before-ff-20260715
git stash push -u -m "QR-invite + polling + badge (WIP 2026-07-15)"
```
> `stash` để tách sạch 8 file WIP ra khỏi cây trước khi FF, tránh Git chặn checkout do local changes.

### Bước 1 — Đưa `giap` lên ngang `main`
Vì `giap` là tổ tiên trực tiếp của `main`, chỉ cần fast-forward:
```bash
git checkout giap
git merge --ff-only origin/main       # FF sạch, không tạo merge commit
```
> Sau bước này, toàn bộ 31 file ở §3 về đúng bản `main`. Chạy kiểm tra ngay:
```bash
flutter pub get && flutter analyze && flutter test
```

### Bước 2 — Khôi phục & tái hoà 3 nhóm WIP

**(A) Giữ nguyên, pop thẳng (không đụng main):**
- `family_shell.dart` (polling), `home_dashboard_screen.dart` (badge), `AndroidManifest.xml`.

**(B) Ghép tay (conflict nhẹ):**
- `child_home_screen.dart` — giữ **cả** shortcut Album (từ main) **và** badge chuông (từ local).

**(C) LÀM LẠI trên luồng mã mời mới (đừng pop nguyên bản):**
- `invite_member_screen.dart`: đổi QR để encode **mã 8 ký tự** (hoặc deep link mang `?code=`) thay vì `?token=`. Dựng QR ngay cạnh mã text `main` đang hiện — QR là bổ sung UX rất hợp lý cho luồng mới.
- `join_family_screen.dart`: giữ nút "Quét QR" + `mobile_scanner`, nhưng `_scanQr()` trả về **mã** → gọi `previewInviteCode(code)` + `requestJoinByCode(code)` của provider mới (KHÔNG dùng `_extractToken`).
- `pubspec.yaml`: **giữ** `qr_flutter` + `mobile_scanner` (main không có; đây là dep mới hợp lệ cho feature QR).

```bash
git stash pop         # rồi giải conflict theo (A)(B)(C) ở trên
```

### Thứ tự ưu tiên (nếu muốn kéo từng phần thay vì FF trọn gói)
| Ưu tiên | Nhóm | Lý do |
|---|---|---|
| 🔴 P0 | `user.dart` + `auth_provider.dart` (`fc59c69`) | Fix phân quyền: `SYSTEM_ADMIN` không còn bị gán nhầm `manager`. |
| 🔴 P0 | Invite-code + join-request (`3c5f9cb`, `invitation_provider` + 3 screen) | Contract BE đang chạy; luồng token cũ đã chết trên prod (xem §7). |
| 🟠 P1 | Finance monthly-summary + `member_finance_screen` (`6d65ee3`) | 4 EP BE mới ship, UC gap #5. |
| 🟠 P1 | Album manual tagging + moderation + mở Deputy/Member (`0c22014`,`6d65ee3`,`ac82b46`) | Album API thật. |
| 🟡 P2 | Subscription fix nháy FREE + CTA hạ gói (`627b2c4`,`3f53424`) | UX, tránh báo động nhầm "mất gói". |
| 🟡 P2 | SOS inline map + SOS_QUICK_MESSAGE (`93612a9`,`3f53424`) | Tính năng an toàn. |
| ⚪ P3 | Rename ledger, docs, test | Đi kèm, ít rủi ro. |

> **Khuyến nghị:** làm **FF trọn gói** (Bước 1) thay vì cherry-pick từng phần — vì các commit đan xen nhau (rename ledger + invite + album trải khắp nhiều file), cherry-pick sẽ sinh conflict còn nhiều hơn FF.

---

## 6. Điểm cần lưu ý sau khi merge (từ `API_MOBILE_AUDIT_2026-07-15.md`)

`main` mang theo audit 15/07. Các mục **BE còn thiếu** mà FE Mobile cần biết để không wire nhầm:

- **Critical:** Không có API location sharing thường (`/location/family|toggle|update` không có trong Swagger). `GpsProvider` sẽ 404 → **ẩn/chặn khỏi demo** cho tới khi BE ship. Family Map (UC79–81) hiện chỉ có location trong SOS alert. `[VERIFY với BE]`
- **High:** Không có `PATCH /auth/me` → Edit Profile chỉ read-only. `[VERIFY]`
- **High:** Không có API user-facing đổi role/relationship/member status → UC17–18 (grant/revoke Deputy) bị block. `[VERIFY]`
- **High:** Không có API Calendar (UC70–72) và AI Assistant → 2 màn này vẫn là UI/demo. `[VERIFY]`
- **Medium:** Chưa có đăng ký FCM token → notification vẫn **poll REST** (đúng lý do feature polling `family_shell.dart` của local tồn tại). Join-request cũng chưa realtime → poll ~12s khi mở màn "Yêu cầu của tôi". `[VERIFY]`
- **Medium:** `GET /finance/ledger/entries` thiếu filter `memberId`.
- **Medium:** Contract subscription chưa nhất quán: runtime trả `FREE/MONTHLY/YEARLY`, schema admin cũ còn `FREE/PLUS/PREMIUM`. `[VERIFY tên & giá plan]`

---

## 7. Diff Swagger — `docs-json.json` (Tuần 9) vs repo `family-care-api.json`

> Yêu cầu: **chỉ báo diff, không ghi đè file**. (Đã tuân thủ — không sửa file nào.)

| File | Ngày | Số endpoint | Trạng thái |
|---|---|---|---|
| `Family_Care_DOC/Tuần 9/docs-json.json` | 15/07 (hôm nay) | **183** | ✅ Mới nhất (có invite-code + join-request + admin + album) |
| `Family_Care_DOC/Tuần 8-Review2/docs-json.json` | — | 172 | Trung gian |
| `SEP-Family-Care-Mobile/family-care-api.json` (trong repo) | 10/07 | **111** | ⚠️ **CŨ** — vẫn còn luồng `/invitations/{token}`, thiếu invite-code/admin/album |

**So `Tuần 9/docs-json.json` với repo `family-care-api.json`: +80 endpoint mới, −8 endpoint đã gỡ.**

### 7.1. 8 endpoint đã BỊ GỠ (chứng minh luồng token đã chết — lý do §4.1 quan trọng)
```
- /admin/invitations
- /admin/invitations/{id}
- /families/{familyId}/invitations
- /families/{familyId}/invitations/{id}/approve
- /families/{familyId}/invitations/{id}/reject
- /invitations/{token}
- /invitations/{token}/claim
- /invitations/{token}/reject
```

### 7.2. 80 endpoint MỚI (gom theo module)

**invite-codes + me/join-requests (6) — thay thế luồng token:**
```
+ /invite-codes/{code}
+ /invite-codes/{code}/join-requests
+ /families/{familyId}/invite-code
+ /families/{familyId}/invite-code/regenerate
+ /families/{familyId}/join-requests  (+ /{id}/approve, /{id}/reject)
+ /me/join-requests  (+ /{id}/cancel)
```

**admin (27):** audit-logs, backups (+restores), dashboard/summary, families/{id}/subscription (+status, manual-renew, sync-stripe), infrastructure/host + docker/containers (+stats, logs), join-requests, payments, provisioning-logs (+retry), revenue/monthly + summary, system/health + runtime.
> Đây là 27 EP mà team backend đang bàn (Swagger thiếu schema response 200, backup DB fail, revenue/monthly trả count thay vì sum, docker socket rỗng…). **App mobile không dùng nhóm admin này** — thuộc Web Admin (React) — nhưng có mặt đầy đủ trong Swagger prod.

**families/albums (13):** media (CRUD + permanent/restore), moderation (+retry), tags (+{tagId}), face-scan/face-suggestions/face-profiles (BE có nhưng FE **cố ý chưa gọi** — chưa bật Face AI).

**families/chat (13):** conversations (+leave), messages (+upload, pin, reactions), participants, pinned-messages, read.

**families/finance (11):** contribution-plans (submit/approve/reject/confirm), contribution-shortage, contribution-suggestions, monthly-finances/members/{id}, monthly-summary/me + members/{id}.

**families/sos (2):** alerts/{id}/location/current, alerts/{id}/locations/batch.

**auth (2):** forgot-password, reset-password.

### 7.3. Khuyến nghị cho Swagger
- File repo `family-care-api.json` (111 EP) **đã lỗi thời** — nếu FE nào còn tra cứu file này sẽ nhầm luồng mời cũ. Nên thay bằng bản `Tuần 9/docs-json.json` (183 EP) khi có dịp (bạn đã chọn *chỉ báo diff* nên tôi **không ghi đè**; khi cần, chỉ việc copy đè là xong).
- 27 EP admin thiếu schema response 200 (chỉ khai báo 403) — đúng như feedback team; đây là việc **của BE**, không phải mobile.

---

## 8. Checklist thao tác

- [ ] `git branch giap-backup-before-ff-20260715`
- [ ] `git stash push -u -m "QR-invite + polling + badge WIP"`
- [ ] `git merge --ff-only origin/main`
- [ ] `flutter pub get && flutter analyze && flutter test` (2 test mới phải xanh)
- [ ] `git stash pop` → giải conflict: (A) giữ polling/badge/manifest, (B) ghép Album+badge ở child_home, (C) **làm lại QR trên mã 8 ký tự** ở invite_member + join_family
- [ ] Giữ `qr_flutter` + `mobile_scanner` trong pubspec
- [ ] Smoke test luồng: tạo mã → quét QR (mã) → gửi join-request → Manager duyệt
- [ ] Ẩn `GpsProvider`/Family Map thường khỏi demo tới khi BE ship location `[VERIFY]`

---

*Ghi chú: báo cáo dựa trên `git fetch origin main` lúc 2026-07-15. Nếu `main` được đẩy thêm commit sau thời điểm này, fetch lại rồi đối chiếu §1.*
