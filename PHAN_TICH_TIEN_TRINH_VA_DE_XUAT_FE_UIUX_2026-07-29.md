# Phan tich tien trinh hien tai va de xuat FE UIUX - 2026-07-29

## Overview

Bao cao nay cap nhat tien trinh FE Mobile Family Care dua tren:
- Code hien tai trong repo Flutter.
- File OpenAPI moi dinh kem `pasted-text.txt`.
- Cac bao cao gan nhat: `PHAN_TICH_API_MOI_2026-07-27.md` va `DE_XUAT_CHINH_SUA_2026-07-29.md`.

Ket luan nhanh:
- FE Mobile da co nen tang kha day du: Auth, Family, Finance, Tasks, SOS, Chat, Calendar, Album/Face, AI Chatbot, Notifications, GPS, Wearables, Subscription.
- OpenAPI moi co 284 endpoint, lon hon dang ke so voi `family-care-api.json` trong repo hien tai chi co 150 endpoint. Can xem file API trong repo la da cu.
- Huong phat trien UIUX nen uu tien "API-driven product surface": moi nhom API tuong ung voi mot workflow ro rang, co loading/error/empty state thong nhat, va phan quyen theo Manager/Deputy/Member.

## Prerequisites

- Repo local: `C:\Users\giaph\Desktop\Family Care\SEP-Family-Care-Mobile`
- Branch hien tai: `giap...origin/giap`
- Trang thai working tree: khong thay file thay doi trong `git status --short --branch`; co warning Git khong doc duoc `C:\Users\giaph/.config/git/ignore`.
- OpenAPI moi: `C:\Users\giaph\.codex\attachments\0ccf30d0-a469-4fde-b76a-00e00b55cc41\pasted-text.txt`
- OpenAPI trong repo: `family-care-api.json`

Lenh da dung de kiem tra:

```powershell
git status --short --branch
rg --files
Get-Content .\PHAN_TICH_API_MOI_2026-07-27.md -TotalCount 220
Get-Content .\DE_XUAT_CHINH_SUA_2026-07-29.md -TotalCount 220
ConvertFrom-Json pasted-text.txt
rg "ApiClient|familyPath\(|/finance|/sos|/albums|/chat|/calendar|/notifications|/wearables|face-profiles" lib/providers lib/screens lib/services lib/navigation -n
```

## Steps

1. Kiem tra trang thai Git va cau truc Flutter.
2. Doc bao cao phan tich API moi ngay 2026-07-27.
3. Doc de xuat chinh sua ngay 2026-07-29.
4. Parse OpenAPI moi de lay tong so endpoint va nhom API.
5. Doi chieu voi provider/screen/router hien co trong `lib/`.
6. Tong hop khoang trong va de xuat huong phat trien FE UIUX.

## Expected Result

### 1. Tong quan API moi

OpenAPI moi co 284 endpoint. Cac nhom lon:

| Nhom API | So endpoint | Y nghia UIUX |
|---|---:|---|
| Finance - Muc tieu tai chinh | 19 | Man muc tieu, tien do, dong gop, thieu hut, phan bo so du |
| Chat | 18 | Inbox, conversation detail, attachment, pin, reaction, read state |
| SOS | 16 | Nut SOS, active alert, tracking location, response, settings, emergency contacts |
| Tasks - Thuong | 16 | Quan ly thuong, settlement, dispute, mark paid/confirm received |
| Auth | 11 | Register/login/Firebase/refresh/logout/me/verify/reset password |
| Admin - Families | 11 | Can Admin UI rieng, khong nen tron vao mobile family flow |
| Finance - Ke hoach ngan sach | 11 | Budget plan, line item, report, state transition |
| Finance - Mo hinh va hu tai chinh | 9 | Models, jars, fund allocations, templates |
| Families | 9 | Family profile, invite code, role, transfer ownership, remove member |
| Calendar | 7 | Event CRUD, cancel, respond, reminder |
| Albums | 7 | Media list/upload/update/delete/restore/permanent delete |
| AI Chatbot | 7 | Conversation, messages, confirm/reject pending action |
| Face Profiles | 6 | Enroll, validate, enable/disable/delete profile |
| Wearables | 6 | Device list, pair, update, delete, events |
| Notifications | 4 | List, unread count, mark read, read all |
| Locations | 3 | Share location, family map, toggle sharing |
| Devices | 2 | FCM device token register/delete |

Nhan xet:
- `family-care-api.json` trong repo chi co 150 endpoint va thieu nhieu module trong OpenAPI moi nhu AI Chatbot, Album moderation, Face Profiles, Wearables, Calendar day du, Admin infrastructure/backup/revenue.
- Can cap nhat lai file API trong repo hoac dat ten version ro rang, vi neu FE tiep tuc doi chieu voi file cu se ra ket luan sai.

### 2. Tien trinh FE hien tai

#### Nen tang da tot

- `ApiClient` da co base URL, bearer token, refresh-token lock, timeout, absolute URL, upload 1 file va upload nhieu file.
- Router da tach shell theo Manager/Deputy/Member, co gate phan quyen va route dung chung cho Chat, Calendar, Map, Album, SOS, Profile.
- Design-system nen tang da co `AppSpacing`, `AppRadius`, `AppShadows`, `AppStatusColors`, `AppCard`, `StatusBadge`, `RetryState`, `EmptyState`, `AppBottomSheetScaffold`.
- Providers da phu phan lon domain chinh: Auth, Family, Finance, Wallet, Task, SOS, Chat, Calendar, Album, Face Profile, AI Chatbot, Notifications, GPS, Wearables, Invitation.

#### Module da gan API kha tot

| Module | Trang thai FE | Ghi chu |
|---|---|---|
| Auth | Da co login/register/Firebase/verify/resend/forgot/reset/logout/me/update profile | Can tiep tuc chuan hoa error copy theo status code |
| Family/Invite | Da co create family, my families, invite code, join request | Con thieu UI tranfer ownership neu API da chot nghiep vu |
| Finance | Da wire rat rong: overview/summary, ledger, categories, models/jars, budget plans, goals, support requests, alerts, reports | La module gan API sau nhat, nhung UI co nguy co qua day dac |
| Tasks | Da co task management, assignment, proof, reward-related screens | Can tach ro workflow "viec can lam hom nay" vs "quan tri task" |
| SOS | Da co trigger/list/detail/location/response/resolve/cancel/settings/emergency contacts | UI SOS hien bi ghi nhan la qua don gian, can nang cap trai nghiem khan cap |
| Chat | Da co conversations, messages, upload, edit/delete, reactions, pin, read, search/shared content | Con phu thuoc pagination de loc media/file |
| Calendar | Da co event list/detail/create/update/cancel/respond/reminder | Can cai thien UX lich theo ngay/tuan va loi moi/tham gia |
| Album/Face | Da co album, tag, face profile enroll/validate, suggestion confirm/reject | Can UI ro hon cho AI suggestion, moderation queue |
| AI Chatbot | Da co conversation/messages va pending action confirm/reject | Nen bien pending action thanh "review before apply" co preview ro |
| Notifications | Da co list/unread/read/read-all va realtime | Can chuan hoa type/icon/deep link |
| GPS/Wearables | Da co map, location sharing, wearables list/pair/update/delete/events | Can gom thanh "Safety devices & location" de tranh bi rai rac |

### 3. Khoang trong theo API moi

#### P0 - Can lam truoc

1. Cap nhat nguon OpenAPI trong repo.
   - Hien `family-care-api.json` cu hon file dinh kem.
   - Nen tao quy trinh: moi lan BE xuat Swagger moi thi replace file API, ghi ngay version, va cap nhat changelog FE.

2. Dong bo UI state/loading/error/empty cho cac man co API phuc tap.
   - Uu tien Finance, SOS, Album/Face, Chat, Calendar.
   - Dung lai `AppCard`, `StatusBadge`, `RetryState`, `EmptyState`, `AppBottomSheetScaffold`.

3. Notification type va deep link.
   - API co `/notifications`, `/unread-count`, `read`, `read-all`.
   - FE can mapping type -> icon -> action route, vi day la trung tam dieu huong den SOS, support request, task, calendar, chat.
   - Can BE document enum notification type.
   - ⚠️ [VERIFY WITH OFFICIAL SOURCE] OpenAPI can xac nhan danh sach type va payload deep-link chinh thuc.

4. SOS UIUX nang cap.
   - Khong chi la mot nut do. Can co 3 trang thai: ready, active alert, resolved/history.
   - Man active alert can co ban do, nguoi da xem, nguoi dang den, lien he khan cap, nut "Toi an toan", nut "Can them tro giup".
   - Settings can tach rieng: emergency contacts, auto location interval, wearable SOS, notification escalation.

5. Album/Face AI flow.
   - Tao moderation queue cho Manager/Deputy.
   - Face suggestion nen hien confidence, ten thanh vien, anh dai dien, nut confirm/reject/change member.
   - ⚠️ [VERIFY WITH OFFICIAL SOURCE] Can BE chot response schema `face-suggestions`, confidence scale 0..1 hay 0..100, va permission remove tag.

#### P1 - Nen lam trong dot UIUX tiep theo

1. Finance information architecture.
   - Tach thanh 5 khu vuc: Overview, Ledger, Budget, Goals, Requests/Alerts.
   - Mobile nen uu tien "viec can xu ly hom nay": request can duyet, alert moi, goal sap tre, budget vuot nguong.
   - Cac bao cao nen co chart nho, filter thang, va drill-down. Tranh hien JSON raw cho nguoi dung cuoi.

2. Task & Reward experience.
   - Manager/Deputy: dashboard phan cong, minh chung can duyet, tranh chap thuong, settlement can chi tra.
   - Member: "Viec cua toi", "Can nop minh chung", "Thuong dang cho".
   - Reward settlement/dispute la nhom API lon nhung can UI rat ro de tranh nham voi Finance ledger.

3. Calendar UX.
   - Can tab Ngay/Tuan/Danh sach.
   - Event detail can hien participant status: accepted/declined/maybe/pending.
   - Notification tu calendar nen deep link vao event detail.

4. Chat UX.
   - Conversation list can co unread badge, last message, pinned entry point.
   - Detail can co shared media/file/link screen rieng.
   - Neu BE chua co filter attachment/messageType thi FE dang phai load nhieu page roi loc, ton request.
   - ⚠️ [VERIFY WITH OFFICIAL SOURCE] De nghi BE them `messageType` filter hoac endpoint attachments rieng.

5. Wearables + Location.
   - Nen gom vao mot hub "An toan & thiet bi".
   - Moi device card can hien owner, battery/status neu co, GPS/SOS toggle, latest event.
   - Family map can hien sharing status cua tung member va thoi diem cap nhat cuoi.

#### P2 - Nen lam sau khi P0/P1 on dinh

1. Admin surface.
   - OpenAPI moi co 35+ endpoint Admin: users, families, subscriptions, backup/restore, audit logs, infrastructure, revenue.
   - Khong nen nhet vao app mobile family hien tai.
   - De xuat lam Admin Web/Tablet rieng: dashboard, user/family management, subscription/payment, system health, backup/restore, audit logs.

2. UI component library noi bo.
   - Chuan hoa form section, list item, metric card, action sheet, confirmation dialog, timeline, avatar stack, member picker, amount input, date range picker.
   - Moi module moi bat buoc dung component chung de giam lech UI.

3. API contract test nhe cho FE.
   - Tao script so sanh endpoint trong OpenAPI voi string path trong provider.
   - Flag endpoint moi chua co owner FE.
   - Flag endpoint FE dang goi nhung khong con trong Swagger.

### 4. De xuat phat trien giao dien FE UIUX theo API

#### Huong san pham

App nen duoc dinh vi la "Family Operations App", khong phai tap hop man hinh tinh nang. Home cua moi role nen tra loi 3 cau hoi:

1. Hom nay toi can lam gi?
2. Co viec nao can xu ly ngay khong?
3. Gia dinh dang o trang thai nao?

#### Navigation de xuat

| Role | Tab nen uu tien | Ly do |
|---|---|---|
| Manager | Home, Chat, Calendar, SOS, Album, Me | Manager can tong quan va dieu phoi |
| Deputy | Home, Tasks, Wallet, SOS, Chat, Me | Deputy can xu ly viec duoc uy quyen |
| Member | Home, Tasks, Wallet, SOS, Chat, Me | Member can lam viec ca nhan va giao tiep |

Route quan tri sau nen dua vao Profile/Home shortcut thay vi lam day bottom nav:
- Finance model
- Budget plans
- Financial goals
- Finance reports
- Members
- Invitation requests
- Subscription
- Wearables
- SOS settings

#### Home dashboard de xuat

Moi role co dashboard rieng:

| Khu vuc | Manager/Deputy | Member |
|---|---|---|
| Safety | SOS active, location sharing, wearable alerts | Nut SOS, chia se vi tri, nguoi dang theo doi |
| Finance | Request can duyet, alert, tong quan thang | Vi cua toi, request cua toi, dong gop muc tieu |
| Tasks | Proof can duyet, task sap den han | Task cua toi, proof can nop, thuong |
| Calendar | Su kien hom nay, loi moi can phan hoi | Su kien hom nay, trang thai tham gia |
| Communication | Chat unread, pinned important | Chat unread |

#### Visual system

- Giu phong cach app operational: ro rang, de scan, it trang tri.
- Status color phai nhat quan theo `AppStatusColors`.
- Card chi dung cho item lap lai hoac surface can nhan manh; tranh long card trong card.
- Bottom sheet dung cho create/edit/detail ngan; full screen cho workflow dai nhu budget plan, SOS active, album moderation.
- Cac man co du lieu tai chinh can co dinh dang tien te dong nhat, khong hien so raw.

#### Component can xay them

| Component | Dung cho API |
|---|---|
| `MemberPickerSheet` | Tasks, Calendar, Chat group, Face suggestion change member |
| `DateRangeFilterBar` | Finance reports, ledger, calendar, admin revenue |
| `ApiStateScaffold` | Loading/error/empty/success cho cac screen list |
| `ActionReviewCard` | AI pending action, support request review, reward dispute |
| `TimelineList` | SOS responses/location, task history, backup/restore, audit logs |
| `AttachmentGrid` | Chat shared media, Album, Task proofs |
| `PermissionAwareActionBar` | Gate action theo Manager/Deputy/Member |
| `MetricStrip` | Finance dashboard, Admin dashboard, SOS stats |

## Troubleshooting

### Van de 1: Swagger trong repo cu hon Swagger moi

Trieu chung:
- Doi chieu FE voi `family-care-api.json` se thieu Chat/AI/Album/Wearables/Admin moi.

Xu ly:
1. Replace hoac them version moi cua OpenAPI vao repo.
2. Ghi ro ngay export va nguon.
3. Cap nhat `API_DOCS.md` va bao cao FE parity.

### Van de 2: Response schema chua du ro

Anh huong:
- FE phai parse phong thu, de sai UI nhu mat ten thanh vien, confidence sai thang do, notification khong map icon/deep link.

Xu ly:
- Gui BE danh sach field can chot: notification type/payload, face-suggestions, album tag permissions, AI pending action preview/status, finance report DTO.
- ⚠️ [VERIFY WITH OFFICIAL SOURCE] Khong dung cac field suy luan cho tai lieu khach hang neu BE chua chot.

### Van de 3: UI qua day dac khi API ngay cang lon

Anh huong:
- Nguoi dung cuoi thay qua nhieu entry point, kho biet viec nao can lam truoc.

Xu ly:
- Phat trien theo dashboard/action-first.
- Cac module phuc tap chi mo sau khi user drill-down tu alert/card/action.
- Dung notification va home cards lam entry point chinh.

## Uu tien de nghi

1. P0: Cap nhat OpenAPI trong repo va lap ma tran API parity moi.
2. P0: Nang cap SOS UIUX thanh workflow khan cap day du.
3. P0: Chuan hoa notification type/deep link.
4. P1: Cai thien Finance IA: Overview, Ledger, Budget, Goals, Requests/Alerts.
5. P1: Lam Album/Face AI moderation queue va face suggestion UX.
6. P1: Gom Wearables + Location thanh hub "An toan & thiet bi".
7. P2: Tach Admin Web/Tablet surface rieng, khong tron vao mobile app gia dinh.
