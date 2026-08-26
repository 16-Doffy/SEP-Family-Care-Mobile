# Kịch bản test luồng Thưởng nhiệm vụ (phát thưởng + tranh chấp)

**Cập nhật:** 26/08/2026 · **Môi trường:** production `https://api.familycare-digital.com/api/v1`

Tài liệu này để **chạy lại được không cần chị/AI** — gồm cả bản test tự động
bằng API lẫn bản bấm tay trên máy thật.

---

## 0. Chuẩn bị

### Tài khoản test (gia đình `NDuy` — `b0cc7942-2a29-42f0-a63b-713bc98295f1`)

| Vai | Email | Ghi chú |
|---|---|---|
| Manager | `ngophamnhutduy050302@gmail.com` | chủ gia đình |
| Deputy | `duynpnse161783@fpt.edu.vn` | đủ quyền quản trị như Manager (trừ 4 quyền riêng) |
| Member | `nhatdeptrai281003@gmail.com` | người nhận thưởng |

> Mật khẩu **không ghi vào file này** (quy ước repo: không commit mật khẩu).
> Hỏi chủ dự án khi cần.

### Lấy token

```bash
API="https://api.familycare-digital.com/api/v1"
mkdir -p tok
lg() {
  curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" > "tok/$3.json"
  node -e "const d0=JSON.parse(require('fs').readFileSync('tok/$3.json','utf8'));
  const d=d0.data||d0;require('fs').writeFileSync('tok/$3.tok',d.accessToken||'');
  console.log('$3', d.accessToken?'OK':'FAIL');"
}
lg "<email-deputy>"  "<mk>" deputy
lg "<email-member>"  "<mk>" member
lg "<email-manager>" "<mk>" owner
```

⚠️ JWT sống **15 phút** — chạy lâu thì lấy lại token.

---

## 1. Enum & ràng buộc đã verify (đừng đoán lại)

| Thứ | Giá trị đúng | Sai thì bị gì |
|---|---|---|
| `rewardType` | `MONEY_RECORD` \| `POINT` \| `OTHER` | `MONEY` → 400 `rewardType không hợp lệ` |
| `externalMethod` | `CASH` \| `BANK_TRANSFER` \| `THIRD_PARTY_WALLET` \| `OTHER` | |
| `action` (tranh chấp) | `ACCEPT_DISPUTE` \| `REJECT_DISPUTE` | |
| `decision` (duyệt bài) | `APPROVED` \| `REJECTED` | |
| Nộp bài | **bắt buộc** có `proofs[]` | rỗng → 400 `Danh sách minh chứng không được để trống` |
| `proofType` | `IMAGE` \| `VIDEO` \| `NOTE` \| `FILE` | |
| Ledger query | chỉ nhận `limit` (≤100) + `page` | `limit=500`, `sortBy`, `entryType` → **400** |
| `member-contribution-summary` | chỉ nhận `periodStart`/`periodEnd` | `month`/`year` → 400 `Trường "month" không được phép` |

---

## 2. Bảng chuyển trạng thái (đã verify đúng)

| Hành động | Ai làm | Trạng thái settlement |
|---|---|---|
| Tạo quyết toán | Manager/Deputy | `PENDING_SETTLEMENT` |
| Đánh dấu đã trả | Manager/Deputy | `WAITING_CONFIRMATION` |
| Member xác nhận đã nhận | Member | `SETTLED` → **sinh bút toán** |
| Member tạo tranh chấp | Member | `DISPUTED` |
| Chấp nhận tranh chấp | Manager/Deputy | về `PENDING_SETTLEMENT` |
| Từ chối tranh chấp | Manager/Deputy | về `WAITING_CONFIRMATION` |

**Bút toán sinh ra khi `SETTLED`** (BE Phase 1, deploy 26/08):
`entryType=REWARD`, `sourceType=TASK_REWARD_SETTLEMENT`, `sourceId=settlementId`,
`entryDate=confirmedAt`, `metadata` có `taskId`/`receiverMemberId`/`rewardSettlementId`.
Chỉ sinh khi `rewardType=MONEY_RECORD` và `amount>0`. Có chống trùng.

⚠️ Settlement **không** trả `ledgerEntryId` → truy ngược bằng
`sourceType=TASK_REWARD_SETTLEMENT` + `sourceId=settlementId`.

---

## 3. Test tự động — luồng chính + tranh chấp

Script: `D:/Temp/fc/reward_flow.js` (19 bước) và `verify_phase1.js` (10 bước).

Khung gọi API dùng chung:

```js
const API='https://api.familycare-digital.com/api/v1';
const FID='b0cc7942-2a29-42f0-a63b-713bc98295f1';
const tok=r=>require('fs').readFileSync(`tok/${r}.tok`,'utf8').trim();
async function call(role,method,path,body){
  const res=await fetch(API+path,{method,
    headers:{Authorization:`Bearer ${tok(role)}`,'Content-Type':'application/json'},
    body:body===undefined?undefined:JSON.stringify(body)});
  let j=null; try{j=await res.json();}catch(_){}
  return {status:res.status, body:j};
}
const un=r=>(r.body&&r.body.data!==undefined?r.body.data:r.body);
```

### Trình tự các lệnh

```
POST   /families/{FID}/tasks                              (deputy)
POST   /families/{FID}/tasks/{taskId}/reward-setting      (deputy)
POST   /families/{FID}/tasks/{taskId}/assignments         (deputy)
PATCH  /families/{FID}/tasks/assignments/{aid}/start      (member)
POST   /families/{FID}/tasks/assignments/{aid}/submissions(member) + proofs[]
PATCH  /families/{FID}/tasks/submissions/{sid}/review     (deputy) decision=APPROVED
POST   /families/{FID}/tasks/submissions/{sid}/reward-settlement (deputy)
PATCH  /families/{FID}/tasks/reward-settlements/{id}/mark-paid   (deputy)
PATCH  /families/{FID}/tasks/reward-settlements/{id}/confirm-received (member)
POST   /families/{FID}/tasks/reward-settlements/{id}/disputes    (member)
PATCH  /families/{FID}/tasks/reward-disputes/{did}/resolve       (deputy)
```

### Kiểm tra phân quyền (phải ra 403)

```
member  PATCH .../submissions/{sid}/review          -> 403
member  PATCH .../reward-settlements/{id}/mark-paid -> 403
member  PATCH .../reward-disputes/{did}/resolve     -> 403
member  POST  /families/{FID}/tasks                 -> 403
```

### Kiểm tra bút toán

```js
// quét hết sổ, limit tối đa 100, phải phân trang
let all=[];
for(let page=1;page<=6;page++){
  const r=await call('owner','GET',
    `/families/${FID}/finance/ledger/entries?limit=100&page=${page}`);
  const l=un(r).items||un(r); all=all.concat(l);
  if(l.length<100) break;
}
const mine=all.filter(e=>e.sourceId===settlementId);
// kỳ vọng: đúng 1 entry, entryType=REWARD, sourceType=TASK_REWARD_SETTLEMENT
```

---

## 4. Test bấm tay trên máy (bắt lỗi giao diện)

API đúng **không** đảm bảo UI đúng — đã có tiền lệ: màn "Tình hình tài chính"
API trả đủ dữ liệu mà màn vẫn báo "chưa có dữ liệu" vì FE đọc sai key.

### 4.1. Vai Manager/Deputy

- [ ] Tạo nhiệm vụ, đặt thưởng tiền → xem card nhiệm vụ có hiện số tiền thưởng
- [ ] Giao việc cho Member → danh sách người nhận **chỉ hiện thành viên ACTIVE**
      (thành viên đã bị xoá không được xuất hiện)
- [ ] Duyệt bài nộp → trạng thái đổi ngay, không phải thoát ra vào lại
- [ ] Mở màn Quản lý thưởng → thấy khoản chờ quyết toán
- [ ] Bấm "Đánh dấu đã trả" → hộp thoại có **cảnh báo vàng** nói rõ khoản này
      không cộng vào thu nhập cá nhân đã khai
- [ ] Chọn từng phương thức trả (Tiền mặt / Chuyển khoản / Ví điện tử / Khác)
- [ ] Sau khi trả → trạng thái "Chờ xác nhận"
- [ ] Khi Member tranh chấp → thấy tranh chấp, xử được cả **chấp nhận** lẫn **từ chối**

### 4.2. Vai Member

- [ ] Thấy nhiệm vụ được giao, bắt đầu làm được
- [ ] Nộp bài **không kèm minh chứng** → phải báo lỗi rõ ràng, không im lặng
- [ ] Nộp bài kèm ảnh/ghi chú → thành công
- [ ] Sau khi Manager trả thưởng → thấy nút **Xác nhận đã nhận** và **Tranh chấp**
- [ ] Bấm Tranh chấp → nhập lý do → trạng thái đổi sang "Đang tranh chấp"
      (không còn hiện "Đã trả, chờ xác nhận")
- [ ] Xác nhận đã nhận → vào **Sổ thu chi** phải thấy dòng
      **"Thưởng nhiệm vụ: {tên việc}"** (có dấu), loại **Khoản chi**, đúng số tiền
- [ ] Mở chi tiết giao dịch → **không** hiện lặp ký hiệu tiền (`77,000 ₫ đ`)

### 4.3. Kiểm tra chéo số liệu

- [ ] Số dư quỹ gia đình giảm đúng bằng số tiền thưởng
- [ ] Tab Tổng quan: "Chi" tăng đúng số tiền thưởng
- [ ] Thu nhập cá nhân đã khai của Member **không đổi** (Phase 1 cố ý không đụng)

---

## 5. Kết quả test các nhánh phụ (chạy 26/08, script `D:/Temp/fc/test_alloc.js`)

### ✅ Phân bổ thưởng vào hũ/mục tiêu — KHÔNG nhân đôi tiền

Đây là nhánh rủi ro nhất, đã kiểm kỹ:

- Thưởng 120k → `SETTLED` → sinh 1 bút toán `REWARD`
- Member phân bổ 50k vào hũ `Savings` → **201 thành công**
- Đếm lại: vẫn **đúng 1** bút toán cho settlement đó; **tổng tiền `REWARD` toàn sổ không đổi**
  (227.000 trước và sau)
- Bản ghi phân bổ có `ledgerEntryId` **trùng đúng id bút toán thưởng** →
  chỉ liên kết vào bút toán có sẵn, không tạo mới. Đúng như BE nói.
- Phân bổ vượt số thưởng → **400 `Tổng số tiền phân bổ không được vượt quá số tiền thưởng`** ✅

Response phân bổ: `{ id, rewardSettlementId, jarId, goalId, ledgerEntryId, amount, allocatedByMemberId, ... }`

### ✅ Huỷ quyết toán — BE chặn đúng

`PATCH .../cancel` trên khoản đã `SETTLED` → **400 `Không thể hủy ghi nhận thưởng đã
hoàn tất, tranh chấp hoặc đã hủy`**. Trạng thái giữ `SETTLED`, bút toán vẫn `ACTIVE`.
Không có chuyện bút toán mồ côi.

### ✅ `rewardType` khác — chỉ `MONEY_RECORD` sinh bút toán

| Loại | Kết quả |
|---|---|
| `MONEY_RECORD` | Sinh 1 bút toán `REWARD` ✅ |
| `POINT` | **0 bút toán** — đúng kỳ vọng |
| `OTHER` | **0 bút toán** — đúng kỳ vọng |

⚠️ **`OTHER` bắt buộc có `rewardDescription`**, thiếu → 400 `Loại thưởng khác bắt
buộc nhập mô tả thưởng`. `MONEY_RECORD` và `POINT` thì không bắt buộc.

### ⏳ Còn lại chưa test

| Nhánh | Cách test |
|---|---|
| **`autoCreateSettlement: true`** | Settlement tự sinh lúc duyệt bài — luồng khác hẳn, đặt `true` lúc tạo reward-setting |
| **Bấm tay qua giao diện** | Xem mục 4 — API đúng không đảm bảo UI đúng |

---

## 6. Lỗi đã tìm & đã fix (đừng báo lại)

| Lỗi | Trạng thái |
|---|---|
| Thưởng `SETTLED` không sinh bút toán | ✅ BE fix (Phase 1, deploy 26/08) |
| `description` không dấu `"Thuong nhiem vu"` | ✅ FE vá hiển thị · ⏳ chờ BE sửa nguồn |
| Sheet chi tiết hiện `77,000 ₫ đ` (lặp ký hiệu) | ✅ FE fix |
| Hộp thoại "Đã trả" không nói rõ tiền chưa vào sổ | ✅ FE fix |
| Màn Tình hình tài chính đọc `items` thay vì `members` | ✅ FE fix |
| Tên hũ tiếng Anh khi lùi tháng cũ | ✅ FE fix |
| `GET /invite-code` Deputy/Member đều đọc được | ⏳ chờ BE (FE đã che nút, không ảnh hưởng) |
