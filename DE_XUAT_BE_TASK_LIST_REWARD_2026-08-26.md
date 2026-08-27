# Đề xuất BE — `GET /families/{id}/tasks` thiếu `rewardSetting`

> ## ✅ ĐÃ XONG — BE deploy 27/08/2026, FE đã gỡ N+1
>
> Verify thật bằng token Manager trên gia đình `NDuy`:
> **50/50 item có field `rewardSetting`**, 25 item có thưởng, việc chưa đặt
> thưởng trả `null` đúng như đề nghị. Shape khớp endpoint riêng:
> `id, taskId, rewardType, rewardAmount, rewardDescription, autoCreateSettlement,
> createdAt, updatedAt`.
>
> **FE đã gỡ toàn bộ N+1**: bỏ tham số `hydrateRewardSettings` và khối
> `Future.wait` gọi `reward-setting` cho từng việc → màn Quản lý nhiệm vụ từ
> **51 request** (1 danh sách + 50 chi tiết) xuống còn **1 request**.
>
> Giữ lại cờ `rewardSettingsHydrated` nhưng nay tính theo việc response **có
> chứa key** `rewardSetting` hay không — nếu sau này BE lỡ bỏ field thì màn hình
> chỉ **thiếu** chip chứ không quay lại khẳng định sai "Chưa đặt thưởng".
>
> Phần dưới giữ nguyên làm hồ sơ.

---


**Ngày:** 26/08/2026 · **Mức độ:** **Nên có** (không chặn nghiệp vụ, nhưng hiển
thị sai thông tin cho người dùng)
**Người kiểm chứng:** FE, đo bằng token thật trên gia đình `NDuy`
(`b0cc7942-2a29-42f0-a63b-713bc98295f1`), API production.

---

## 1. Hiện trạng

`GET /families/{familyId}/tasks?limit=100` trả về mỗi item đúng 14 field:

```
id, familyId, taskCategoryId, title, description, taskType, priority,
status, createdByMemberId, dueAt, createdAt, updatedAt, category,
createdByMember
```

→ **Không có `rewardSetting`** (cũng không có `rewardAmount`/`rewardType`).

Trong khi đó endpoint riêng `GET /families/{familyId}/tasks/{taskId}/reward-setting`
trả đầy đủ:

```json
{ "rewardType": "MONEY_RECORD", "rewardAmount": 33000, "autoCreateSettlement": true }
```

## 2. Hệ quả trên app

Màn "Quản lý nhiệm vụ" hiện danh sách 50 nhiệm vụ. Vì không có dữ liệu thưởng,
**mọi thẻ nhiệm vụ đều hiện chip "Chưa đặt thưởng"** — kể cả nhiệm vụ đã đặt
thưởng 33.000đ và đã quyết toán xong.

Người quản lý nhìn danh sách sẽ tưởng chưa việc nào có thưởng, dẫn tới đặt
thưởng trùng hoặc bỏ sót.

Muốn biết đúng thì phải mở từng nhiệm vụ ra xem — 50 nhiệm vụ là 50 lần mở.

## 3. FE đang phải chữa cháy bằng N+1 request

FE **đã** gọi `reward-setting` cho **từng** nhiệm vụ sau khi tải danh sách
(`fetchTasks(hydrateRewardSettings: true)`) — tức **50 request** cho một lần mở
màn Quản lý nhiệm vụ. Vừa chậm vừa dội tải BE, nhưng không còn cách nào khác.

Kèm theo đó là hai lỗi FE phát sinh **chỉ vì** phải chữa cháy kiểu này (đã sửa
26/08 nhưng sẽ biến mất hẳn nếu BE trả sẵn field):

1. **8 chỗ gọi `fetchTasks()` không kèm cờ hydrate** (duyệt bài, tạo/sửa/huỷ
   việc…) → vừa duyệt bài xong là **toàn bộ chip thưởng biến mất**, phải thoát
   ra vào lại mới thấy.
2. **Không phân biệt được "chưa đặt thưởng" với "chưa nạp xong"** → trong lúc
   50 request đang chạy (hoặc khi một số request lỗi), mọi nhiệm vụ đều hiện
   "Chưa đặt thưởng" kể cả việc đã có thưởng.

Nếu BE trả sẵn `rewardSetting` trong danh sách thì **cả 50 request lẫn 2 lỗi
trên đều biến mất**.

## 4. Đề xuất

Thêm `rewardSetting` vào mỗi item của response `GET /families/{id}/tasks`, dùng
đúng khuôn endpoint riêng đang trả:

```json
{
  "id": "...",
  "title": "...",
  "rewardSetting": {
    "rewardType": "MONEY_RECORD",
    "rewardAmount": 33000,
    "rewardDescription": null,
    "autoCreateSettlement": false
  }
}
```

Nhiệm vụ chưa đặt thưởng thì trả `"rewardSetting": null` — FE phân biệt được
"chưa đặt" với "không biết".

## 5. Phía FE đã làm gì trong lúc chờ (26/08)

- `fetchTasks` nay **nhớ** lựa chọn hydrate của màn đang mở, nên các lần refresh
  nội bộ (duyệt bài, tạo/sửa/huỷ việc) không còn làm mất chip thưởng.
- Thêm cờ `rewardSettingsHydrated`: chip **"Chưa đặt thưởng"** chỉ hiện **sau
  khi** đã nạp xong. Trước đó không hiện gì — thà thiếu thông tin còn hơn khẳng
  định sai.

Cả hai đều là chữa cháy. BE trả sẵn `rewardSetting` trong danh sách thì gỡ được
N+1 request lẫn cờ này.
