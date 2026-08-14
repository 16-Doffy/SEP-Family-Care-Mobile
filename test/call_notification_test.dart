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

  test('có callId thì mở entry route cuộc gọi đến', () {
    for (final role in UserRole.values) {
      final path = routeFor(role)!;
      expect(path, startsWith('/incoming-call/'));
      expect(path, contains('callId=call-1'));
    }
  });

  test('thiếu referenceId vẫn mở được khung chat', () {
    // Không có callId thì không fetch được `GET /calls/{callId}`; fallback về
    // chat theo role để người dùng vẫn thấy dòng log CALL nếu BE đã tạo.
    for (final id in [null, '']) {
      expect(routeFor(UserRole.member, referenceId: id), '/member/chat');
    }
  });

  test('CALL có callId là overlay route → nơi gọi dùng context.push', () {
    expect(
      NotificationRouter.isShellBranch(routeFor(UserRole.manager)!),
      isFalse,
    );
    expect(
      NotificationRouter.isShellBranch(
        routeFor(UserRole.manager, referenceId: null)!,
      ),
      isTrue,
    );
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
