# Báo cáo BE — Face AI, quyền thành viên và Feature Access

> Ngày: 2026-07-21 · Phạm vi: Family Care Mobile Flutter
> Nguồn đối chiếu: Swagger production `/api/docs-json` và yêu cầu BE cùng ngày.

## 1. Blocker — Face Profile upload mâu thuẫn với Swagger

Yêu cầu trao đổi nói FE upload từng ảnh một. Tuy nhiên Swagger production của
`POST /families/{familyId}/face-profiles/{memberId}/enroll` quy định multipart:

- field `files`: mảng binary, `minItems: 3`, `maxItems: 5`;
- field `consentConfirmed`: bắt buộc.

Không có endpoint upload tạm/từng ảnh, upload session hoặc finalize. FE hiện
triển khai đúng Swagger: người dùng chọn 3–5 ảnh rồi gửi **một** multipart
request. Cần BE chốt một trong hai phương án:

1. Giữ batch upload: xác nhận field multipart chính xác là `files` (không phải
   `files[]`) và kích thước/MIME ảnh được chấp nhận; hoặc
2. Muốn upload tuần tự: bổ sung contract create upload session → upload từng
   ảnh → finalize/enroll khi đủ 3–5 ảnh.

### Kết quả test runtime 2026-07-21

FE đã gửi thành công một multipart với `files` gồm 3 ảnh và
`consentConfirmed=true`; BE phản hồi `Face image is not enrollable`. Điều này
xác nhận field multipart hiện tại được BE nhận và lỗi nằm ở bước kiểm tra/nhận
diện ảnh phía BE, không phải luồng gửi file của Mobile.

Đề nghị BE trả error code và chi tiết an toàn theo từng file (ví dụ ảnh nào
không có mặt, nhiều mặt, khuôn mặt quá nhỏ, chất lượng thấp hay format/size
không hỗ trợ) để FE hướng dẫn người dùng thay đúng ảnh thay vì chỉ nhận một
message chung.

## 2. Blocker — Family-facing Role / Relationship / Deputy API chưa có

Mobile có family detail, approve join request và remove member. Mobile không
có API family-facing để Manager sửa thành viên đã tồn tại:

- `relationship`;
- `familyRole`;
- grant/revoke Deputy.

Không dùng admin API cho Mobile. Đề nghị contract:

`PATCH /families/{familyId}/members/{memberId}`

Body tối thiểu:

```json
{ "familyRole": "FAMILY_MEMBER|DEPUTY_MEMBER", "relationship": "..." }
```

Cần chốt `memberId` là FamilyMember.id hay User.id, role nào được phép gọi,
và rule không hạ/xóa Family Manager cuối cùng.

## 3. Face AI suggestion — phần cần BE chốt

FE đã wire scan, list, confirm và reject theo API hiện có. Vẫn cần BE xác nhận:

- response/status chính thức của face profile và scan (`PROCESSING`, `READY`,
  `FAILED`, `DISABLED`, không phát hiện mặt...);
- schema suggestion: member, confidence, status;
- `confirm` có tự tạo album tag hay FE phải gọi tags tiếp;
- chưa có contract cho yêu cầu **"chọn thành viên khác"** khi confirm sai;
- quyền gọi scan/confirm/reject theo role và feature plan.

## 4. Feature Access cần BE enforce và trả đầy đủ

Swagger đã công bố key như `album.faceSuggestions`, `album.videoUpload`,
`calendar.*`, `finance.*`, `sos.*`, `chat.*`, `ai.*`. Cần đảm bảo
`GET /families/{familyId}/subscription` luôn trả object featureAccess đầy đủ
cho plan hiện tại (Free/Monthly/Yearly), không phải `{}`.

Mọi API premium phải BE enforce server-side và trả error code phân biệt
`FEATURE_LOCKED` với 403 do role/ownership. Nếu không, FE không thể hiện chính
xác dialog nâng gói.

## 5. Album filter chưa có query contract

Yêu cầu filter: tất cả, có tôi, theo member, chưa tag, có AI suggestion. API
list album hiện chỉ có contract FE đã dùng cho page/limit/mediaType/moderation.
Cần BE chốt query chính thức, ví dụ `taggedMemberId`, `untagged`,
`hasFaceSuggestions`, và response pagination tương ứng.

## 6. Cần nghiệm thu runtime

- Test Face Profile 3, 4, 5 và 2/6 ảnh; MIME/size/error mapping.
- Test profile disabled không sinh suggestion và enable lại hoạt động.
- Test scan khi plan Free/Paid, scan trùng, không có mặt, lỗi AI.
- Test confirm/reject từ hai thiết bị và tag chỉ xuất hiện sau confirm.
- Test user không đủ role gọi API trực tiếp nhận 403 rõ ràng.
