import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/user.dart';
import 'package:family_care/navigation/notification_router.dart';

// Bối cảnh: BE bật notification cho gọi video ngày 11/08/2026 —
// `referenceType: 'CALL'`, `referenceId` là `callId`. Gửi cho mọi participant
// khác lúc khởi tạo, và thêm một push riêng "Cuộc gọi nhỡ" khi hết 30 giây
// không ai bắt máy.
//
// Vì sao cần test: đợt 1 ngày 11/08 phát hiện Swagger **tự mâu thuẫn** — enum
// `NotificationType` đã có `CALL` nhưng `NotificationResponseDto.referenceType`
// thì chưa. BE đã sửa sau khi FE hỏi, và giá trị chốt là `'CALL'`. Sai một ký
// tự thì bấm vào thông báo cuộc gọi **không mở màn nào và không báo lỗi** —
// đúng loại bug đã xảy ra vài lần ở module Notification.
void main() {
  String? routeFor(UserRole role, {String? referenceId = 'call-1'}) =>
      NotificationRouter.routeFor(
        referenceType: 'CALL',
        referenceId: referenceId,
        role: role,
      );

  test('CALL có màn đích cho MỌI role', () {
    // Ai cũng có thể nhận cuộc gọi, kể cả Member — không được gate theo quyền
    // quản lý như BUDGET_ALERT hay JOIN_REQUEST.
    for (final role in UserRole.values) {
      expect(routeFor(role), isNotNull, reason: 'role $role không có màn đích');
    }
  });

  test('mỗi role về đúng shell của mình', () {
    expect(routeFor(UserRole.manager), '/manager/chat');
    expect(routeFor(UserRole.deputy), '/deputy/chat');
    expect(routeFor(UserRole.member), '/member/chat');
  });

  test('thiếu referenceId vẫn mở được khung chat', () {
    // Màn đích hiện chưa dùng tới callId, nên push thiếu field cũng không
    // được dẫn tới ngõ cụt.
    for (final id in [null, '']) {
      expect(routeFor(UserRole.member, referenceId: id), '/member/chat');
    }
  });

  test('đích là nhánh của shell → nơi gọi phải dùng context.go', () {
    // Dùng context.push cho path thuộc StatefulShellRoute sẽ dựng shell thứ
    // hai trùng GlobalKey và crash Navigator (xem ghi chú trong CLAUDE.md).
    expect(NotificationRouter.isShellBranch(routeFor(UserRole.manager)!), isTrue);
  });

  test('giá trị lạ vẫn fail-open, không crash', () {
    // referenceType phía BE là string tự do; bản build cũ gặp giá trị mới phải
    // nằm im ở danh sách chứ không được nổ.
    expect(
      NotificationRouter.routeFor(
        referenceType: 'CALL_SOMETHING_NEW',
        referenceId: 'x',
        role: UserRole.member,
      ),
      isNull,
    );
  });
}
