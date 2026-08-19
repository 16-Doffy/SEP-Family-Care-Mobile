# Phân tích SOS Wearable — Té ngã / Nhịp tim giả lập & kích hoạt SOS

Ngày soạn: 2026-08-19 · Nhánh: `giap`.

Phương pháp: đọc trực tiếp source code đang có trong working tree (không suy đoán từ tên file/tài
liệu), đối chiếu với `API_DOCS.md`/swagger, và đối chiếu chéo với các báo cáo BE trước đó
(`CODEX_MEMORY_WEARABLE_SOS_2026-08-16.md`, `SO_SANH_TRUOC_SAU_WEARABLE_SOS_2026-08-16.md`,
`docs/KICH_BAN_DEMO_HOI_DONG_5_SCENARIO_2026-08-18.md`) để xác nhận cái nào còn đúng, cái nào đã lỗi
thời. Mọi số dòng (`file.dart:12`) trỏ đúng vị trí trong code tại thời điểm soạn tài liệu này.

---

## 0. Tóm tắt nhanh

1. **Rủi ro hiểu nhầm mà bạn lo ngại là có thật, và đúng với code đang chạy hôm nay** — không phải
   hiểu nhầm sai của người xem. 3 nút "Giả lập té ngã / nhịp tim cao / nhịp tim thấp" hiện tại **gọi
   thẳng hàm tạo cảnh báo** (`_raise(trigger)`) ngay khi bấm, y hệt cơ chế của nút SOS thủ công về
   mặt trải nghiệm (bấm → đếm ngược → gửi). Điểm khác biệt thật sự (endpoint khác, BE tự quyết định
   có tạo cảnh báo hay không, chống trùng) **hoàn toàn nằm ở tầng dưới, không có gì trên UI thể hiện
   ra** — người xem không có cách nào tự nhận ra sự khác biệt nếu không được giải thích bằng lời.
2. **Phát hiện quan trọng nhất của phiên phân tích này**: đội đã từng nhận ra đúng vấn đề này và
   **sửa xong, test pass thật trên thiết bị** (16–17/08/2026) — chuyển 3 nút giả lập từ "bấm ra kết
   quả" sang "phát tín hiệu cảm biến → detector tự phân tích → chỉ khi detector kết luận bất thường
   mới mở cảnh báo". Nhưng bản sửa đó **đã bị mất khỏi working tree** trong một lần đồng bộ nhánh
   `NDuy` (17/08/2026 23:02), chỉ còn sót lại 2 file dịch vụ mồ côi
   (`lib/services/heart_rate_detector.dart`, `lib/services/wearable_sos_snooze_service.dart`) không
   được import ở bất kỳ đâu ngoài chính chúng và file test — xem mục 8 để xem bằng chứng đầy đủ.
   `docs/KICH_BAN_DEMO_HOI_DONG_5_SCENARIO_2026-08-18.md` (mục 6) đã tự phát hiện và ghi chú đúng
   điều này trước khi tôi bắt đầu phân tích — tài liệu này xác nhận lại phát hiện đó bằng bằng chứng
   git cụ thể hơn (patch backup, lịch sử commit).
3. **Không cần hỏi thêm BE về cơ chế cốt lõi** — BE đã trả lời đầy đủ nhiều vòng (16–17/08) về điều
   kiện auto-create, chống trùng, quyền sở hữu thiết bị, snooze là FE-local. Chỉ có 2 điểm "nên có"
   (không bắt buộc) đáng gửi thêm, xem `DE_XUAT_BE_SOS_WEARABLE_EVENT_TRACEABILITY_2026-08-19.md`.

---

## 1. Đính chính bản kiến trúc "tham khảo" trong yêu cầu của bạn

Đối chiếu với source thật, bản mô tả sơ bộ bạn đưa ra là **đúng với code đang chạy hôm nay** ở gần
như mọi điểm — đội trước đó đã đọc đúng source. Vài điểm bổ sung/làm rõ:

- **Đúng**: đồng hồ không có kênh gọi BE qua trung gian điện thoại lúc runtime; nó tự có
  `accessToken`/`refreshToken` riêng sau khi `claim`, tự gọi thẳng BE. Không có luồng "đồng hồ →
  điện thoại → BE" nào tồn tại trong code — điều bạn đã tự đính chính trong tin nhắn là chính xác.
- **Đúng**: SOS thủ công đi thẳng `POST /sos/alerts` với `sourceType: WEARABLE`; té ngã/nhịp tim đi
  qua `POST /wearables/{deviceId}/events`, BE tự quyết định tạo SOS.
- **Cần bổ sung**: mô tả của bạn nói "3 nút giả lập — vì máy ảo không có sensor thật" như một sự
  thật hiển nhiên đã hoàn thiện. Thực tế đúng là 3 nút đó tồn tại vì lý do đó, nhưng **cách chúng
  hoạt động hiện tại (gọi thẳng kết quả, không mô phỏng tín hiệu) chính là nguồn gốc của rủi ro hiểu
  nhầm bạn đang hỏi** — xem mục 5 và 7.
- **Cần bổ sung**: bảng so sánh của bạn thiếu 1 chi tiết quan trọng — `rawValue` gửi lên cho cả 3
  trigger hiện tại là **hằng số cố định trong code**, không phải giá trị đo được (xem mục 5.2). Đây
  là điểm khác với những gì báo cáo `CODEX_MEMORY_WEARABLE_SOS_2026-08-16.md` mô tả (báo cáo đó mô
  tả một phiên bản đã tính `rawValue` từ kết quả detector thật — phiên bản đó không có trong code
  hiện tại).

---

## 2. Luồng SOS thủ công trên đồng hồ (đối chiếu, không đổi)

File: [`lib/wear/screens/wear_sos_screen.dart`](lib/wear/screens/wear_sos_screen.dart)

1. Giữ nút tròn đỏ 2 giây (`_onHoldStart`/`_onHoldEnd`,
   [wear_sos_screen.dart:63-92](lib/wear/screens/wear_sos_screen.dart#L63)) — có haptic đếm ngược,
   thả tay giữa chừng thì huỷ, không gọi API gì.
2. Hết 2 giây → `_triggerSOS()` ([wear_sos_screen.dart:94-131](lib/wear/screens/wear_sos_screen.dart#L94))
   gọi `SosProvider.sendSos(sourceType: 'WEARABLE')` →
   `POST /families/{familyId}/sos/alerts` với body:
   ```json
   { "sourceType": "WEARABLE", "triggerReason": "MANUAL", "message": "SOS từ đồng hồ FamilyCare" }
   ```
   (xem [sos_provider.dart:638-663](lib/providers/sos_provider.dart#L638)) — **tạo cảnh báo vô điều
   kiện**, không có bước BE "cân nhắc có nên tạo hay không", không chống trùng SOS active.
3. Có `alertId` → đồng hồ mới hỏi GPS của chính nó (`resolveWearableSosPosition()`), đẩy 1 điểm qua
   `POST /sos/alerts/{alertId}/locations` với `sourceType: WEARABLE_GPS`
   ([wear_sos_screen.dart:135-173](lib/wear/screens/wear_sos_screen.dart#L135)) — best-effort, lỗi
   không rollback alert.
4. Trong lúc alert còn `ACTIVE`, cứ 30 giây gửi lại 1 điểm
   (`_locationStreamPeriod`, [wear_sos_screen.dart:23](lib/wear/screens/wear_sos_screen.dart#L23)) —
   dừng lại nếu 3 lần gửi liên tiếp lỗi
   ([wear_sos_location_stream_guard.dart:2](lib/wear/wear_sos_location_stream_guard.dart#L2)) hoặc
   nếu alert không còn `ACTIVE` nữa.
5. Huỷ dùng `POST /sos/alerts/{alertId}/confirm-safety`
   ([sos_provider.dart:750-766](lib/providers/sos_provider.dart#L750)) — không dùng `cancel` vì
   Swagger giới hạn `cancel` cho Manager/Deputy, còn người đeo thường chỉ là Member.

Không có gì để sửa ở luồng này — ổn định, đã verify nhiều lần (✅ theo kịch bản demo).

---

## 3. Luồng té ngã / nhịp tim — cơ chế THẬT đang chạy hôm nay

File: [`lib/wear/screens/wear_sensor_sos_screen.dart`](lib/wear/screens/wear_sensor_sos_screen.dart)
(sửa lần cuối tại commit `a1b0dcd`, theo spec "Wear OS Flow" 04/08/2026 — comment đầu file
[dòng 15-30](lib/wear/screens/wear_sensor_sos_screen.dart#L15) tự ghi rõ đây là thiết kế cố ý, không
phải bug).

### 3.1. Hai nguồn kích hoạt trên cùng một màn

- **Cảm biến thật**: toggle "Phát hiện té ngã" ([dòng 384-399](lib/wear/screens/wear_sensor_sos_screen.dart#L384))
  bật `FallDetectorService.instance.start(onFall: () => _raise(_Trigger.fall))`
  ([dòng 136-144](lib/wear/screens/wear_sensor_sos_screen.dart#L136)). Dịch vụ này
  ([fall_detector_service.dart](lib/services/fall_detector_service.dart)) đọc gia tốc kế thật (50ms/mẫu),
  chạy máy trạng thái **rơi tự do → va đập** (`freeFallThreshold=6.0 m/s²`, `impactThreshold=25.0
  m/s²`, cửa sổ va đập 900ms, cooldown 30s — [dòng 61-67](lib/services/fall_detector_service.dart#L61)).
  Đây là logic thật, có test riêng (`test/fall_detection_test.dart`), **không phải phần cần sửa**.
- **3 nút "Giả lập (demo)"** ([dòng 401-418](lib/wear/screens/wear_sensor_sos_screen.dart#L401)): mỗi
  nút gọi thẳng `onTap: () => _raise(t)` — **giống hệt cách `FallDetectorService` gọi `_raise` khi
  phát hiện té ngã thật**. Đây chính là điểm mấu chốt: về mặt code, nút giả lập và cảm biến thật đi
  vào **đúng một điểm vào** (`_raise`), nên kiến trúc là đúng đắn (không tách riêng 2 luồng). Nhưng
  vì nút giả lập **không đi qua bất kỳ bước phân tích/mô phỏng tín hiệu nào trước khi gọi `_raise`**,
  trải nghiệm người bấm y hệt "bấm nút → tạo cảnh báo", không có gì gợi ý rằng nó đang giả lập một
  *sự kiện cảm biến* thay vì giả lập một *cú bấm SOS khác*.

### 3.2. `rawValue` là hằng số cố định, không phải kết quả đo

Extension `_TriggerSpec` ([dòng 41-97](lib/wear/screens/wear_sensor_sos_screen.dart#L41)) định nghĩa
sẵn `rawValue` cho từng trigger:

```dart
_Trigger.fall => {'gForce': 3.2, 'stillSeconds': 8, 'source': 'wear_os_emulator'},
_Trigger.heartHigh => {'heartRate': 142, 'thresholdHigh': 130, 'durationSeconds': 30, 'source': 'wear_os_emulator'},
_Trigger.heartLow => {'heartRate': 38, 'thresholdLow': 50, 'durationSeconds': 30, 'source': 'wear_os_emulator'},
```

Số `142 bpm` / `38 bpm` hiển thị trên UI ([dòng 56-60](lib/wear/screens/wear_sensor_sos_screen.dart#L56))
và số gửi lên BE **là cùng một hằng số viết sẵn trong code** — không có "cảm biến nhịp tim giả lập"
nào thực sự chạy, không có phép đo nào, không có ngưỡng nào được kiểm tra tại runtime cho 2 case
nhịp tim. Với case té ngã, nếu bật "Cảm biến thật" thì có phân tích thật (mục 3.1); nhưng nếu bấm nút
"Giả lập té ngã" thì cũng chỉ gửi thẳng `gForce: 3.2` cố định, không chạy qua `FallDetector`.

### 3.3. Đếm ngược 20 giây — nơi duy nhất người dùng còn có thể huỷ

`_raise()` ([dòng 146-165](lib/wear/screens/wear_sensor_sos_screen.dart#L146)) mở màn cảnh báo với
`_countdownSeconds = 20` ([dòng 101](lib/wear/screens/wear_sensor_sos_screen.dart#L101)). Bấm "Con
ổn"/"Đã ổn" → `_dismiss()` ([dòng 168-175](lib/wear/screens/wear_sensor_sos_screen.dart#L168)) chỉ
tắt countdown, **không gọi API nào** — đúng theo xác nhận của BE (`BE_CONFIRM_SOS_SNOOZE_DISMISS_2026-08-17.md`:
dismiss trong countdown không cần BE biết).

### 3.4. Gọi BE và BE tự quyết định

Hết giờ hoặc bấm "Gửi SOS" → `_send(trigger)`
([dòng 177-221](lib/wear/screens/wear_sensor_sos_screen.dart#L177)) gọi
`WearableProvider.createEvent(...)` →
`POST /families/{familyId}/wearables/{deviceId}/events`
([wearable_provider.dart:400-416](lib/providers/wearable_provider.dart#L400)) với body:

```json
{
  "eventType": "FALL_DETECTED",                 // hoặc HEART_RATE_ABNORMAL
  "severity": "HIGH",                            // chỉ gửi cho fall; nhịp tim bỏ trống, BE default CRITICAL
  "rawValue": { "gForce": 3.2, "stillSeconds": 8, "source": "wear_os_emulator" },
  "detectedAt": "2026-08-19T.....Z"               // FE tự set giờ hiện tại (UTC)
}
```

**BE là bên duy nhất quyết định có tạo SOS hay không** — điều kiện đã được BE xác nhận trực tiếp
(16–17/08/2026, `CODEX_MEMORY_WEARABLE_SOS_2026-08-16.md`, đối chiếu lại
`BE_CONFIRM_CONTRACT_SOS_WEARABLE_FINAL_2026-08-17.md`):

| Điều kiện | `FALL_DETECTED` | `HEART_RATE_ABNORMAL` (cao & thấp) |
|---|---|---|
| `device.pairingStatus = PAIRED` | Bắt buộc | Bắt buộc |
| `device.sosEnabled = true` | Bắt buộc | Bắt buộc |
| Family SOS `isEnabled = true` | Bắt buộc | Bắt buộc |
| `autoCreateAlertFromFall = true` | **Bắt buộc** | Không liên quan |
| Nếu thiếu 1 điều kiện | Event vẫn lưu, `alertCreated=false`, `alertId=null` | Event vẫn lưu, `alertCreated=false`, `alertId=null` |
| Nếu người đeo đã có SOS `ACTIVE` | `alertCreated=false`, `alertId=<alert active hiện có>` | như cột trái |
| Alert đứng tên ai | `device.ownerMemberId` (người đeo, không phải người đang login nếu khác — nhưng BE yêu cầu Wear OS phải login đúng owner) | như cột trái |

Response mẫu ([`WearableEventIngestResponseDto`](API_DOCS.md), field `alertCreated`/`alertId`):

```json
{ "event": { "id": "...", "eventType": "FALL_DETECTED", ... }, "alertId": "abc-123", "alertCreated": true }
```

**Hạn chế đã biết**: BE hiện **không trả `reasonCode`** khi `alertCreated=false` — FE (và người
xem demo) không có cách nào phân biệt "vì `autoCreateAlertFromFall=false`" hay "vì
`device.sosEnabled=false`" hay "vì family SOS tắt" chỉ từ response, phải tự biết trước qua cài đặt đã
tải sẵn. Xem đề xuất ở mục 6.

### 3.5. Sau khi có `alertId`

`CreateSensorEventDto` **không có trường vị trí** — alert do BE tạo từ sự kiện cảm biến mặc định
không có toạ độ. Đồng hồ tự bù bằng cách gọi lại đúng cơ chế "hỏi GPS → push 1 điểm → lặp lại 30s"
giống hệt mục 2 bước 3-4 ([dòng 225-298](lib/wear/screens/wear_sensor_sos_screen.dart#L225)).

### 3.6. Huỷ báo động

Giống SOS thủ công: `confirmSafety(alertId)`, không dùng `cancel`
([dòng 300-328](lib/wear/screens/wear_sensor_sos_screen.dart#L300)).

---

## 4. Bảng so sánh 3 luồng (cập nhật, chính xác theo code hiện tại)

| | SOS thủ công (đồng hồ) | Té ngã/nhịp tim (đồng hồ, **hiện tại**) | Té ngã (điện thoại, nền tách biệt) |
|---|---|---|---|
| Endpoint | `POST /sos/alerts` | `POST /wearables/{id}/events` | `POST /sos/alerts` |
| BE tự quyết định tạo alert? | Không — luôn tạo | **Có** — theo bảng điều kiện mục 3.4 | Không — luôn tạo |
| Chống trùng SOS active | Không | **Có** (BE tự chặn) | Không |
| Dữ liệu gửi lên phản ánh gì | Ý định người bấm | **Về nguyên tắc: kết quả phân tích cảm biến. Thực tế hôm nay: hằng số cố định** (mục 3.2) | Kết quả `FallDetector` thật trên điện thoại |
| Có bước "detector phân tích trước khi mở cảnh báo"? | N/A | **Không** — nút giả lập gọi thẳng `_raise` | Có — `FallDetector` thật |
| UI có truyền tải sự khác biệt kiến trúc cho người xem không? | — | **Không** — xem mục 5 | — |

---

## 5. Vì sao rủi ro hiểu nhầm là thật, cụ thể ở đâu

Bạn lo ngại: *"tránh trường hợp người xem hiểu nhầm khi thực hiện kích hoạt giả lập trên wearable
thì sẽ nghĩ rằng chỉ là một nút để kích hoạt SOS khác"*. Đối chiếu với code:

1. **Không có phản hồi trực quan nào phân biệt "giả lập tín hiệu" với "bấm nút tạo cảnh báo"** —
   bấm nút → countdown 20s → gửi. Bấm giữ nút SOS thủ công → countdown 2s → gửi. Cùng một mẫu hình
   "bấm rồi đếm ngược rồi tạo cảnh báo", chỉ khác số giây đếm ngược. Người xem không rành code không
   có cách nào tự suy ra rằng phía sau là 2 endpoint khác nhau, 2 cơ chế BE khác nhau.
2. **Không có bước hiển thị "đang đọc tín hiệu / đang phân tích"** trước khi mở countdown — countdown
   mở ra **ngay lập tức** khi bấm ([dòng 146-165](lib/wear/screens/wear_sensor_sos_screen.dart#L146)),
   không có độ trễ hay animation nào gợi ý "hệ thống vừa phân tích xong dữ liệu cảm biến".
3. **`rawValue` là hằng số** (mục 3.2) — kể cả khi mở DevTools/log để "chứng minh" đây là dữ liệu
   cảm biến thật với hội đồng, số liệu vẫn giống hệt mỗi lần bấm, không có gì thay đổi theo thời gian
   thực để thuyết phục đây là một phép đo.
4. **Không có gate/tiền kiểm tra** trước khi cho bấm nút giả lập — màn chỉ khoá khi `!paired`
   ([dòng 415](lib/wear/screens/wear_sensor_sos_screen.dart#L415)), không kiểm tra `device.sosEnabled`,
   family SOS `isEnabled`, hay `autoCreateAlertFromFall` trước khi cho bấm. Nếu demo bấm "Giả lập
   té ngã" mà `autoCreateAlertFromFall=false`, BE âm thầm không tạo cảnh báo — kết quả trên UI là
   "Đã gửi sự kiện" (không phải "Đã gửi SOS", xem [dòng 460-480](lib/wear/screens/wear_sensor_sos_screen.dart#L460))
   nhưng nếu người trình bày không để ý phân biệt 2 câu chữ rất giống nhau này, rất dễ nói nhầm với
   hội đồng là "đã tạo SOS thành công" trong khi thực ra không có gì được tạo.

**Kết luận**: đây không phải là rủi ro do người xem hiểu sai — hệ thống **thật sự đang vận hành đúng
như một nút tạo cảnh báo trực tiếp về mặt trải nghiệm**, dù đằng sau nó có cơ chế BE tinh vi hơn. Sự
khác biệt là có thật ở tầng dữ liệu/BE nhưng **0% được thể hiện ở tầng giao diện**.

---

## 6. Phát hiện: bản sửa đúng vấn đề này đã có, nhưng bị mất khỏi working tree

### 6.1. Bản sửa đó là gì

`CODEX_MEMORY_WEARABLE_SOS_2026-08-16.md` và `SO_SANH_TRUOC_SAU_WEARABLE_SOS_2026-08-16.md` mô tả
chi tiết một phiên làm việc (ký tên "Codex", một AI agent khác từng chạy trên repo này) đã:

- Thêm `HeartRateDetector` ([lib/services/heart_rate_detector.dart](lib/services/heart_rate_detector.dart) —
  **file này vẫn còn**, thuần logic, có test) — bpm phải vượt ngưỡng **đủ lâu** (`minAbnormalDuration`,
  mặc định logic yêu cầu duy trì bất thường, không phải một mẫu tức thời) mới kết luận bất thường.
- Mở rộng `FallDetectorService` để phát callback `onSample`/`onFallResult` realtime, không chỉ
  `onFall` khi đã kết luận xong.
- Đổi 3 nút "Giả lập..." thành 3 nút "Chạy tín hiệu..." — bấm vào **chạy một chuỗi mẫu tín hiệu giả
  lập** (bình thường → rơi tự do → va đập, hoặc bpm tăng dần), UI hiển thị **realtime** giá trị đo
  và trạng thái phân tích (`Bình thường`, `Rơi tự do`, `Va đập mạnh`, `Nghi té ngã`, `Nhịp tim vượt
  ngưỡng`...) — **chỉ khi detector tự kết luận bất thường thì mới mở countdown 20s**, không mở ngay
  khi bấm nữa.
- `rawValue` gửi BE đổi từ hằng số sang tính từ chính kết quả detector (`impactMagnitudeMs2`,
  `impactG`, `freeFallMs`, mảng `samples` tóm tắt) — số liệu **thay đổi thật theo mỗi lần chạy**.
- Thêm snooze: bấm "Con ổn"/"Đã ổn" chỉ tạm hoãn 15 phút (tuỳ chỉnh được) cho đúng loại trigger đó,
  không tắt vĩnh viễn detector — đã có `WearableSosSnoozeService`
  ([lib/services/wearable_sos_snooze_service.dart](lib/services/wearable_sos_snooze_service.dart) —
  **file này cũng còn**, có test, dùng `flutter_secure_storage`, reset về mặc định mỗi ngày mới).

Theo nhật ký trong `CODEX_MEMORY_WEARABLE_SOS_2026-08-16.md`, bản sửa này **đã build APK, cài lên Wear
OS emulator + Oppo Reno5 thật, chạy E2E thành công**, ghi đúng 3 event vào BE, và test snooze cũng đã
chạy qua UI thật (xem log "17/08/2026... Bấm 'Đã ổn'. FE không gửi SOS... hiển thị snooze notice:
'Nhịp tim bất thường tạm hoãn tới 08:24'"). Đây **chính xác** là hướng giải quyết cho lo ngại của bạn:
mô phỏng **tín hiệu**, để **thuật toán** ra quyết định, thay vì mô phỏng **kết quả**.

### 6.2. Bằng chứng bản sửa đã mất, và mất ở đâu

Working tree hiện tại (`git status`) chỉ còn 4 file mới **chưa track**:

```
?? lib/services/heart_rate_detector.dart
?? lib/services/wearable_sos_snooze_service.dart
?? test/heart_rate_detector_test.dart
?? test/wearable_sos_snooze_service_test.dart
```

Không có `wear_sensor_sos_screen.dart`, `fall_detector_service.dart`, `sos_provider.dart`,
`wearable_provider.dart`, `sos_screen.dart` nào xuất hiện là "đã sửa" — nghĩa là 4 file đó đang ở
**đúng bản đã commit trước phiên Codex** (commit `a1b0dcd`, spec 04/08), không có dấu vết chỉnh sửa
nào của phiên 16-17/08. Tôi tìm thấy lý do: repo có sẵn 1 file backup

```
.codex/backups/before-sync-nduy-20260817-230214.cached.patch
```

— đúng như tên gọi, đây là bản backup **được tạo trước khi đồng bộ với nhánh `NDuy`** lúc 23:02 ngày
17/08/2026 (encode UTF-16, đã giải mã để đọc). Patch này **chứa đúng 7 file**:

```
lib/providers/sos_provider.dart
lib/providers/wearable_provider.dart
lib/screens/shared/sos_screen.dart
lib/services/fall_detector_service.dart
lib/services/sos_realtime_service.dart
lib/wear/screens/wear_sensor_sos_screen.dart
test/fall_detection_test.dart
```

Đây chính xác là danh sách file được liệt kê trong `SO_SANH_TRUOC_SAU_WEARABLE_SOS_2026-08-16.md` là
"đã thay đổi". Kết luận: **thao tác đồng bộ với nhánh `NDuy` (một lệnh git nào đó — merge/reset/checkout
— không rõ chính xác lệnh) đã ghi đè các file đã track về lại bản commit cũ**, chỉ có 4 file **chưa
từng track** (`heart_rate_detector.dart`, `wearable_sos_snooze_service.dart` + 2 test) là sống sót,
vì git không đụng tới file chưa track khi checkout/reset các file đã track.

**`git apply` thô thất bại** (7/7 file báo `patch does not apply`) vì các commit sau đó (đặc biệt
`756dbe6` — fix Garmin) đã sửa tiếp những vùng code trùng lặp. **Nhưng có cách khôi phục tốt hơn hẳn,
đã kiểm chứng thật**: reflog cho thấy `git reset` lúc 23:02:31 (17 giây sau khi patch backup được tạo)
đưa HEAD từ commit `5ee88d8` (đúng lúc chứa bản sửa Codex) về `origin/NDuy`. Vì bản sửa từng được
`git add` (không commit) trước khi bị `reset`, **các blob nội dung "sau khi sửa" của cả 7 file vẫn
còn nguyên trong object database của repo** (`git cat-file -t <hash>` xác nhận tồn tại cho cả 7 file,
xem `index oldhash..newhash` trong patch) — dữ liệu **không hề mất ở tầng git**, chỉ mất khỏi working
tree/staging.

Từ đó tôi dựng lại đúng 3 phiên bản của từng file (bản gốc trước khi Codex sửa, bản Codex đã sửa xong,
bản hiện tại đã có thêm fix Garmin) và chạy `git merge-file` (3-way merge thật, không phải patch mù
theo số dòng) — **kết quả: cả 7/7 file merge sạch, 0 conflict marker**, nghĩa là bản sửa Codex và các
commit sau này (Garmin, v.v.) không đụng trùng vùng code nào. Đã xác nhận bản merge chứa đúng
`HeartRateDetector`, `WearableSosSnoozeService`, `_runFallSignal`/`_runHeartRateSignal`, nhãn nút
"Chạy tín hiệu...". **Kết luận: khôi phục hoàn toàn khả thi và rủi ro thấp hơn nhiều so với đánh giá
ban đầu của tôi** — không cần đối chiếu tay từng đoạn, chỉ cần áp bản merge rồi build/test lại. Tôi
chưa ghi đè file nào trong working tree — kết quả merge hiện chỉ nằm ở
`...scratchpad\3way\*.merged`, chờ bạn xác nhận trước khi áp dụng thật (theo đúng "Rule 3: preview
trước khi sửa").

### 6.3. `docs/KICH_BAN_DEMO_HOI_DONG_5_SCENARIO_2026-08-18.md` đã tự phát hiện đúng việc này

Mục 6 của file đó (soạn 18/08, tức **sau** khi việc mất code đã xảy ra) đã tự đối chiếu source và ghi
rõ: *"Đối chiếu trực tiếp source hiện tại... cho thấy điều này CHƯA xảy ra thật... Có khả năng bản sửa
bị mất trong lần đồng bộ nhánh NDuy ngày 17/08 nhưng chưa xác định chắc chắn nguyên nhân."* — tài
liệu phân tích này xác nhận lại đúng giả thuyết đó bằng bằng chứng git cụ thể hơn (mục 6.2), và kết
luận: **không phải nghi ngờ, mà chắc chắn đã mất, có patch backup để tham chiếu lúc khôi phục.**

---

## 7. Kế hoạch đề xuất

Ràng buộc quan trọng đã ghi trong bộ nhớ dự án: **hội đồng bảo vệ sắp tới → ưu tiên ổn định, hạn chế
thay đổi lớn**. Vì vậy chia kế hoạch thành 2 track theo mức rủi ro/thời điểm, **không tự ý thực hiện
track nào — đây là đề xuất chờ bạn chọn**.

### Track A — An toàn, có thể làm ngay trước ngày bảo vệ (rủi ro thấp)

**Cập nhật 2026-08-19**: đã tách kế hoạch chi tiết + câu hỏi đồng bộ với BE ra file riêng —
[`BAO_CAO_BE_KE_HOACH_WEARABLE_SENSOR_UI_PREFLIGHT_2026-08-19.md`](BAO_CAO_BE_KE_HOACH_WEARABLE_SENSOR_UI_PREFLIGHT_2026-08-19.md).
Theo yêu cầu, **chưa code Track A** — chờ BE xác nhận 2 điểm nhỏ trong file đó (độ trễ cập nhật cài
đặt, độ tin cậy field `device.sosEnabled`) trước khi triển khai, dù cả 2 endpoint dùng đều đã có sẵn
và không cần BE làm gì mới.

Không đụng lại logic đã mất, chỉ vá đúng chỗ hở hiện tại bằng thay đổi nhỏ, dễ test lại nhanh:

1. **Thêm dòng phụ đề giải thích ngay dưới "Giả lập (demo)"** trên màn `WearSensorSosScreen` — ví
   dụ: *"Mô phỏng một sự kiện cảm biến gửi lên máy chủ — máy chủ tự quyết định có tạo cảnh báo hay
   không, khác với nút SOS thủ công."* Thay đổi 1 dòng UI, không đụng logic gọi API, rủi ro gần như
   0. (File: `wear_sensor_sos_screen.dart`, quanh dòng 402.)
2. **Thêm tiền kiểm tra trước khi cho bấm nút giả lập** — tải `SosProvider.fetchSettings()` +
   `device.sosEnabled` trong `initState` (tương tự những gì Codex đã làm và test qua, xem mục 6.1),
   khoá nút kèm lý do rõ ràng nếu gia đình đã tắt SOS/tắt `autoCreateAlertFromFall` — tránh tình
   huống bấm "Giả lập té ngã" trước hội đồng mà không có gì xảy ra vì thiếu cài đặt, gây bối rối tại
   chỗ. Đây là phần dễ nhất trong bản sửa đã mất để làm lại độc lập, vì không phụ thuộc detector.
3. **Cập nhật kịch bản thuyết trình** (đã có sẵn trong `docs/KICH_BAN_DEMO_HOI_DONG_5_SCENARIO_2026-08-18.md`
   mục 6, câu hỏi hội đồng dự kiến) — thêm đúng 1 câu giải thích ngắn gọn khi bấm nút giả lập: *"Nút
   này gửi một sự kiện cảm biến lên máy chủ giống hệt cách cảm biến thật sẽ gửi; máy chủ — không
   phải ứng dụng — là bên quyết định có tạo cảnh báo khẩn cấp hay không, dựa trên cài đặt gia đình đã
   bật."* Đây là hành động 0-rủi-ro-code, chỉ là script nói, nhưng giải quyết đúng 80% lo ngại của
   bạn cho buổi bảo vệ sắp tới.

### Track B — Khôi phục đầy đủ cơ chế "tín hiệu → detector → cảnh báo"

**✅ ĐÃ ÁP DỤNG 2026-08-19** (theo yêu cầu trực tiếp của bạn). Phạm vi khôi phục cố ý **thu hẹp hơn**
patch gốc — chỉ lấy đúng phần "Wearable detect giả lập té ngã, nhịp tim phát SOS", bỏ 3 file không
liên quan (xem giải thích bên dưới):

| File | Trạng thái |
|---|---|
| `lib/wear/screens/wear_sensor_sos_screen.dart` | Đã áp — signal simulator + realtime analysis + snooze + tiền kiểm tra `_canStartSignal`/`_blockedReason` |
| `lib/services/fall_detector_service.dart` | Đã áp — thêm `FallAnalysisPhase`, `FallDetectionReading`, `FallDetectionResult`, callback `onSample`/`onFallResult` |
| `lib/providers/wearable_provider.dart` | Đã áp — bỏ `detectedAt` khỏi payload `createEvent`, để BE dùng server time (né lệch giờ Wear emulator) |
| `test/fall_detection_test.dart` | Đã áp — thêm test khoá đúng chuỗi mẫu signal simulator |
| `lib/providers/sos_provider.dart` | **Không áp** — patch gốc chỉ xoá 2 dòng comment ở `_applyRealtimeResponderLocation`, không liên quan tính năng wearable |
| `lib/services/sos_realtime_service.dart` | **Không áp** — patch gốc thêm auto-`connect()` khi push responder-location thất bại, thuộc tính năng "theo dõi vị trí người ứng cứu" khác, ngoài phạm vi yêu cầu |
| `lib/screens/shared/sos_screen.dart` | **Không áp** — patch gốc thêm cơ chế theo dõi vị trí responder + debug log, cùng lý do trên |

Đã xác nhận: `flutter analyze` (8 file liên quan + toàn repo `--no-fatal-infos`) → 0 lỗi, chỉ còn các
`info` đã tồn tại từ trước ở file khác không liên quan. `flutter test` cho
`fall_detection_test.dart`, `heart_rate_detector_test.dart`, `wearable_sos_snooze_service_test.dart`,
`wear_overflow_test.dart`, `wearable_mapping_test.dart` → **124/124 pass**. Đang chạy `flutter test`
toàn repo để chắc chắn không có regression ở màn/provider khác dùng chung `wearable_provider.dart`.

**Cập nhật: `flutter test` toàn repo → 536/536 pass, exit code 0** — không có regression ở bất kỳ màn/
provider nào khác trong dự án.

Việc còn lại — **kế hoạch cũ dưới đây** (đối chiếu patch, build, cài lên thiết bị) đã hoàn thành phần
code. Phần *duy nhất* còn treo là bước 4: test E2E cầm tay thật trên Wear OS emulator (không có
wearable Wear OS thật, theo bạn xác nhận) trước khi coi là sẵn sàng demo trước hội đồng.

---

**Kế hoạch gốc (để tham khảo, đã thực hiện phần 1-3):**

**Cập nhật 2026-08-19 — ràng buộc thiết bị test**: bạn xác nhận **không có wearable Wear OS thật**.
Setup test khả thi duy nhất là những gì phiên Codex 16-17/08 đã dùng trước đó (xem
`CODEX_MEMORY_WEARABLE_SOS_2026-08-16.md`): **Wear OS emulator** (`emulator-5556`, model
`sdk_gwear_x86_64`) cho phần UI/luồng logic, cộng thêm **1 điện thoại Android thật cài build target
`lib/wear/main_wear.dart`** đóng vai trò "wearable giả lập có gia tốc kế thật" (phiên trước dùng Oppo
Reno5) nếu muốn kiểm tra nhánh "Cảm biến thật". Vì không có smartwatch thật, phần cảm biến nhịp tim
**vẫn chỉ kiểm tra được qua signal simulator**, không có cách nào đo nhịp tim thật trên emulator/điện
thoại thường — đây là giới hạn đã biết từ trước, không phải giới hạn mới phát sinh do thiếu thiết bị.
Track B vẫn đang **để sau ngày bảo vệ** theo đúng ràng buộc ổn định mùa bảo vệ — chưa bắt đầu.

**Cập nhật 2026-08-19 — khôi phục dễ hơn dự kiến ban đầu**: sau khi kiểm tra sâu hơn (mục 6.2), việc
**áp lại code** (bước 1-2 dưới đây) hoá ra rất nhẹ — 3-way merge tự động sạch 100%, không cần đối
chiếu tay. Cái thật sự cần chờ sau mùa bảo vệ là **bước 4 (test E2E trên thiết bị thật)**, vì bạn
không có wearable thật. Có thể tách 2 việc: (a) áp merge + `flutter analyze`/`flutter test` ngay bây
giờ mà không có rủi ro cho bản build đang dùng để demo (chỉ áp khi bạn xác nhận, chưa tự động làm),
(b) để việc tập dượt demo bằng emulator/Oppo thật sự sau khi yên tâm về thời gian.

1. Đối chiếu thủ công patch đã mất (`before-sync-nduy-20260817-230214.cached.patch`, đã giải mã sẵn)
   với code hiện tại của 7 file liên quan, merge lại phần logic detector-mediated — **không thể áp
   patch tự động**, phải đọc từng hunk vì đã có commit `756dbe6` (Garmin) chồng lên.
2. Wire `HeartRateDetector` (đã có sẵn, chưa dùng) và `WearableSosSnoozeService` (đã có sẵn, chưa
   dùng) vào `wear_sensor_sos_screen.dart` theo đúng luồng đã mô tả ở mục 6.1.
3. Chạy lại toàn bộ 121 test đã pass trước đó (`test/fall_detection_test.dart`,
   `test/heart_rate_detector_test.dart`, `test/wearable_sos_snooze_service_test.dart`,
   `test/wear_overflow_test.dart`, `test/wearable_mapping_test.dart`) + `flutter analyze`.
4. Test lại E2E trên Wear OS emulator + 1 thiết bị thật trước khi coi là xong — đây là bước tốn thời
   gian nhất, đúng lý do nên để sau mùa bảo vệ.
5. Cân nhắc thêm test widget khoá riêng cho `WearSensorSosScreen` (mục "Ưu tiên tiếp theo" #4 trong
   `CODEX_MEMORY_WEARABLE_SOS_2026-08-16.md` cũng đã tự đề xuất việc này) để tránh mất lần nữa mà
   không ai phát hiện ngay — hiện tại không có test nào khoá đúng hành vi "nút giả lập gọi `_raise`
   trực tiếp hay qua detector", nên lần mất trước không bị `flutter test` bắt được.

### Việc không nên làm trước ngày bảo vệ

- Không chạy lại thao tác đồng bộ/merge nhánh `NDuy` mà không kiểm tra kỹ trạng thái working tree
  trước — đúng nguyên nhân gây mất lần này.
- Không thử khôi phục Track B bằng `git apply` trực tiếp — đã xác nhận patch không áp được, làm ẩu sẽ
  tạo conflict markers lẫn vào source.

---

## 8. Việc đã gửi BE / còn cần gửi BE

BE **đã trả lời đầy đủ** những câu hỏi cốt lõi liên quan đến cơ chế `FALL_DETECTED`/
`HEART_RATE_ABNORMAL`, chống trùng, quyền sở hữu thiết bị, và xác nhận snooze là xử lý phía FE, không
cần BE tham gia (xem lịch sử trong `CODEX_MEMORY_WEARABLE_SOS_2026-08-16.md` các mục "BE confirm..."
16-17/08). **Không cần hỏi lại các điểm đó.**

Có đúng 2 điểm mới, dạng "nên có" chứ không chặn demo, đáng gửi thêm — đã tách riêng thành:
[`DE_XUAT_BE_SOS_WEARABLE_EVENT_TRACEABILITY_2026-08-19.md`](DE_XUAT_BE_SOS_WEARABLE_EVENT_TRACEABILITY_2026-08-19.md).

---

## 9b. Cập nhật sau phản hồi BE (2026-08-19, cuối ngày)

BE/nhóm đã thống nhất: **ưu tiên Track A cho mùa bảo vệ, không làm Track B lúc này** (rủi ro cao, cần
test lại nhiều — đúng như khuyến nghị ở mục 7). 2 câu hỏi ở mục 8 **chưa có câu trả lời dứt khoát** từ
BE về độ trễ cache — BE hướng dẫn: cứ triển khai Track A theo hướng an toàn, kèm nút làm mới thủ công
để né rủi ro cache cũ thay vì chờ câu trả lời.

**Diễn biến quan trọng**: bản khôi phục Track B đã áp ở mục 7 (trước đó) **đã bị revert về đúng bản
gốc đơn giản** (qua một phiên làm việc khác của user, xác nhận qua `git diff` rỗng so với HEAD) trước
khi phản hồi BE tới. Track A vì vậy được cài **trực tiếp trên nền bản gốc đơn giản**, không dựa trên
code Track B đã mất — đúng tinh thần "không làm Track B lúc này".

**Đã triển khai Track A** trên `lib/wear/screens/wear_sensor_sos_screen.dart` (file duy nhất cần sửa,
không đụng `fall_detector_service.dart`/`wearable_provider.dart` vì Track A không cần detector thật):

1. `initState` gọi thêm `SosProvider.fetchSettings()` (trước đó chỉ có `fetchCurrentDevice()`).
2. Thêm `_canStartSignal(trigger)` / `_blockedReason(trigger)` / `_showSignalBlocked(trigger)` — gate
   đúng 3 điều kiện BE yêu cầu: `device.sosEnabled`, family SOS `isEnabled`, và riêng té ngã thêm
   `autoCreateAlertFromFall`. Bấm nút khi chưa đủ điều kiện → hiện lý do cụ thể qua `_error` (khung
   lỗi đã có sẵn trên UI), không còn đếm ngược 20s rồi mới biết "không có gì xảy ra".
3. Thêm dòng mô tả ngay dưới nhãn "Giả lập (demo)": *"Gửi một sự kiện cảm biến lên máy chủ — máy chủ
   tự quyết định có tạo cảnh báo hay không, khác với nút SOS thủ công."*
4. Thêm nút làm mới (icon refresh nhỏ ở góc header) gọi lại cả `fetchCurrentDevice()` +
   `fetchSettings()` — theo đúng hướng dẫn của BE để né rủi ro cache cũ trước demo.

Đã verify: `flutter analyze` file vừa sửa → 0 lỗi. `flutter test` toàn repo → **535/535 pass**, exit
code 0 (giảm 1 test so với lúc Track B còn áp, vì `fall_detection_test.dart` đã quay về bản gốc cùng
lúc bị revert — đúng dự kiến, không phải regression).

File đề xuất BE (`DE_XUAT_BE_SOS_WEARABLE_EVENT_TRACEABILITY_2026-08-19.md`, `reasonCode`/
`isSimulated`) — BE xác nhận chỉ ghi nhận cho cải tiến sau, không chặn gì hiện tại.

Track B (detector đầy đủ) — **chính thức để sau mùa bảo vệ**, không còn trong code hiện tại.

### Bổ sung cùng ngày: hiệu ứng "biến động" trên UI (không phải detector thật)

User yêu cầu thêm hiển thị số liệu biến động trên UI khi bấm nút giả lập (thay vì đứng yên 1 số).
Đã thêm `_Trigger.signalReadings` + `_runSignal()` trong `wear_sensor_sos_screen.dart`: chạy một chuỗi
chuỗi text cố định (260ms/bước, ví dụ té ngã `1.0g → 0.9g → 0.3g → 0.1g → 0.2g → 1.8g → 3.2g → 1.0g`)
hiện ngay trên subtitle của tile đang bấm, xong mới gọi `_raise(trigger)` y hệt luồng cũ.

**Cố ý khác Track B ở điểm mấu chốt**: đây thuần là hiệu ứng UI (`Timer.periodic` đổi text), **không
có class detector nào phân tích/quyết định** — giá trị cuối cùng của chuỗi luôn khớp đúng
`rawValue`/`reading` gốc đã gửi BE (`gForce: 3.2`, `heartRate: 142`, `heartRate: 38`), không đổi
payload, không đổi logic quyết định mở cảnh báo. Giữ đúng ranh giới BE đã chốt: "chưa làm Track B".

`flutter analyze` 0 lỗi. `flutter test` toàn repo → **535/535 pass**, exit code 0.

### Bổ sung thêm cùng ngày: "hệ thống phát hiện được mới cảnh báo" (không tự động mở sau khi chạy hết chuỗi)

User chỉ ra đúng: bản đầu tiên của hiệu ứng biến động **luôn** gọi `_raise()` sau khi chuỗi chạy xong,
bất kể giá trị cuối là gì — nghĩa là về hành vi vẫn "mở cảnh báo vô điều kiện", chỉ khác vỏ ngoài. Đã
sửa lại `_runSignal()`: mỗi mẫu trong chuỗi được so với `_Trigger.isAbnormal(value)` — ngưỡng lấy
đúng số đã gửi BE (`thresholdHigh: 130`, `thresholdLow: 50`; té ngã dùng mốc va đập `2.5g`, dưới mẫu
cuối `3.2g` nên chuỗi demo cố định luôn kết ở đúng mẫu phát hiện được). **Chỉ khi một mẫu thật sự vượt
ngưỡng thì mới gọi `_raise()`** — nếu hết chuỗi mà không mẫu nào vượt ngưỡng, quay lại trạng thái bình
thường, không mở cảnh báo (nhánh này không xảy ra với dữ liệu demo cố định hiện tại vì luôn có mẫu
cuối vượt ngưỡng, nhưng code xử lý đúng nếu sau này đổi dữ liệu mẫu).

**Vẫn cố ý khác Track B**: đây là so ngưỡng đơn giản 1 lần/mẫu, không phải thuật toán đầy đủ (rơi tự
do + thời gian duy trì) của `FallDetector`/`HeartRateDetector` thật — không dùng lại 2 class đó, vẫn
mồ côi như cũ. Nhưng đúng yêu cầu: có bước "phát hiện" thật sự quyết định, không phải luôn luôn báo
động sau khi hiệu ứng chạy xong.

`flutter analyze` 0 lỗi. `flutter test` toàn repo → **535/535 pass**, exit code 0.

---

## 9. Đã chốt (2026-08-19)

1. **Track A**: chưa code — đã tách kế hoạch + câu hỏi đồng bộ BE ra
   [`BAO_CAO_BE_KE_HOACH_WEARABLE_SENSOR_UI_PREFLIGHT_2026-08-19.md`](BAO_CAO_BE_KE_HOACH_WEARABLE_SENSOR_UI_PREFLIGHT_2026-08-19.md).
   Chờ bạn gửi file đó cho BE và nhận xác nhận 2 điểm nhỏ, rồi quay lại nhờ code.
2. **Track B**: để sau ngày bảo vệ, có ghi nhận ràng buộc không có wearable thật (mục 7).
3. **Đề xuất BE** (`DE_XUAT_BE_SOS_WEARABLE_EVENT_TRACEABILITY_2026-08-19.md`): sẵn sàng, bạn tự gửi
   cho team Backend khi thuận tiện.
