import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/wearable_provider.dart';

/// Khoá contract parse của `WearableDevice` theo `SosWearableDeviceResponseDto`.
///
/// Đáng test vì đây là model đứng giữa lỗi "ngắt kết nối báo thành công khống":
/// `pairingStatus` sai một nhịp là UI nói khác server, người dùng ghép lại nhận
/// 409 mà không hiểu vì sao (xem DE_XUAT_BE_WEARABLE_UNPAIR_2026-08-06.md).
void main() {
  /// Response đúng như Swagger mô tả cho một thiết bị đang ghép nối.
  Map<String, dynamic> paired() => {
    'id': 'device-1',
    'workspaceId': 'family-1',
    'ownerMemberId': 'member-1',
    'deviceName': 'Đồng hồ của Ba',
    'deviceType': 'SMARTWATCH',
    'deviceIdentifier': 'watch-serial-001',
    'pairingStatus': 'PAIRED',
    'gpsEnabled': true,
    'sosEnabled': true,
    'lastSeenAt': '2026-08-06T10:00:00.000Z',
    'createdAt': '2026-08-01T00:00:00.000Z',
    'updatedAt': '2026-08-06T10:00:00.000Z',
  };

  group('WearableDevice — schema chính thức', () {
    test('đọc đủ field của SosWearableDeviceResponseDto', () {
      final d = WearableDevice.fromJson(paired());

      expect(d.id, 'device-1');
      expect(d.deviceName, 'Đồng hồ của Ba');
      expect(d.deviceType, 'SMARTWATCH');
      expect(d.deviceIdentifier, 'watch-serial-001');
      expect(d.pairingStatus, 'PAIRED');
      expect(d.gpsEnabled, isTrue);
      expect(d.sosEnabled, isTrue);
      expect(d.ownerMemberId, 'member-1');
      expect(d.lastSeenAt, isNotNull);
    });

    test('id đọc được cả `id` (Swagger) lẫn `deviceId`', () {
      expect(WearableDevice.fromJson({'id': 'a'}).id, 'a');
      expect(WearableDevice.fromJson({'deviceId': 'b'}).id, 'b');
      // `deviceId` được ưu tiên vì một số response lồng dùng tên này.
      expect(WearableDevice.fromJson({'deviceId': 'b', 'id': 'a'}).id, 'b');
    });

    test('giữ nguyên payload gốc trong `raw`', () {
      // updateDevice() dựng lại device từ `raw` khi cập nhật lạc quan; mất raw
      // là mất các field FE chưa map (workspaceId, createdAt...).
      final d = WearableDevice.fromJson(paired());
      expect(d.raw['workspaceId'], 'family-1');
      expect(d.raw['createdAt'], '2026-08-01T00:00:00.000Z');
    });
  });

  group('WearableDevice — pairingStatus quyết định luồng ghép nối', () {
    test('UNPAIRED thì isPaired phải là false', () {
      final d = WearableDevice.fromJson({
        ...paired(),
        'pairingStatus': 'UNPAIRED',
      });
      expect(d.isPaired, isFalse);
      expect(d.isLost, isFalse);
    });

    test('LOST (báo mất) cũng không còn là đang ghép nối', () {
      final d = WearableDevice.fromJson({...paired(), 'pairingStatus': 'LOST'});
      expect(d.isPaired, isFalse);
      expect(d.isLost, isTrue);
    });

    test('không phân biệt hoa thường', () {
      expect(
        WearableDevice.fromJson({'pairingStatus': 'paired'}).isPaired,
        isTrue,
      );
      expect(WearableDevice.fromJson({'pairingStatus': 'lost'}).isLost, isTrue);
    });

    test('BE không trả pairingStatus → mặc định PAIRED (fail-safe có chủ ý)', () {
      // Đây là hướng an toàn ĐÚNG cho luồng gỡ: `unpairDevice` xác minh lại bằng
      // GET /wearables/me và ném lỗi nếu còn PAIRED. Mặc định PAIRED nghĩa là
      // thiếu dữ liệu thì báo "chưa gỡ được" chứ không báo thành công khống.
      final d = WearableDevice.fromJson({'id': 'device-1'});
      expect(d.pairingStatus, 'PAIRED');
      expect(d.isPaired, isTrue);
    });
  });

  group('WearableDevice — giá trị thiếu và tên chủ thiết bị', () {
    test('thiếu tên/loại thì dùng mặc định hiển thị được', () {
      final d = WearableDevice.fromJson({'id': 'device-1'});
      expect(d.deviceName, 'Thiết bị đeo');
      expect(d.deviceType, 'SMARTWATCH');
      expect(d.deviceIdentifier, isEmpty);
    });

    test('ownerName đọc từ ownerMember.displayName trước', () {
      final d = WearableDevice.fromJson({
        'id': 'device-1',
        'ownerMember': {
          'id': 'member-9',
          'displayName': 'Ba',
          'user': {'fullName': 'Nguyễn Văn A'},
        },
      });
      expect(d.ownerName, 'Ba');
      expect(d.ownerMemberId, 'member-9');
    });

    test('không có displayName thì lùi về ownerMember.user.fullName', () {
      final d = WearableDevice.fromJson({
        'id': 'device-1',
        'ownerMember': {
          'id': 'member-9',
          'user': {'fullName': 'Nguyễn Văn A'},
        },
      });
      expect(d.ownerName, 'Nguyễn Văn A');
    });

    test('BE không trả gì về chủ thiết bị thì để null, UI tự ẩn dòng đó', () {
      final d = WearableDevice.fromJson({'id': 'device-1'});
      expect(d.ownerMemberId, isNull);
      expect(d.ownerName, isNull);
    });

    test(
      'lastSeenAt ưu tiên lastSeenAt, sau đó lastEventAt, rồi updatedAt',
      () {
        DateTime? seen(Map<String, dynamic> j) =>
            WearableDevice.fromJson({'id': 'd', ...j}).lastSeenAt;

        expect(
          seen({'lastSeenAt': '2026-08-06T10:00:00.000Z'})?.isUtc,
          isFalse,
        );
        expect(seen({'lastEventAt': '2026-08-05T10:00:00.000Z'})!.year, 2026);
        // Cảnh báo có chủ ý: thiếu cả hai thì rơi về updatedAt, nên "lần cuối
        // thấy thiết bị" có thể thực ra là lần cuối bản ghi bị sửa.
        expect(seen({'updatedAt': '2026-08-04T10:00:00.000Z'})!.day, 4);
        expect(seen({}), isNull);
      },
    );

    test('cờ boolean chỉ nhận bool thật, chuỗi "true" KHÔNG được tính', () {
      // Ghi lại hành vi hiện tại để nếu BE đổi sang serialize chuỗi thì test này
      // đỏ ngay, thay vì âm thầm tắt GPS/SOS trên UI.
      expect(WearableDevice.fromJson({'gpsEnabled': true}).gpsEnabled, isTrue);
      expect(
        WearableDevice.fromJson({'gpsEnabled': 'true'}).gpsEnabled,
        isFalse,
      );
      expect(WearableDevice.fromJson({}).sosEnabled, isFalse);
    });
  });

  group('WearableEvent — sự kiện cảm biến', () {
    test('đọc eventType và severity theo enum của BE', () {
      final e = WearableEvent.fromJson({
        'id': 'event-1',
        'eventType': 'HEART_RATE_ABNORMAL',
        'severity': 'HIGH',
        'detectedAt': '2026-08-06T10:00:00.000Z',
      });
      expect(e.eventType, 'HEART_RATE_ABNORMAL');
      expect(e.severity, 'HIGH');
      expect(e.detectedAt, isNotNull);
    });

    test('thiếu severity thì mặc định LOW', () {
      expect(
        WearableEvent.fromJson({
          'id': 'e',
          'eventType': 'FALL_DETECTED',
        }).severity,
        'LOW',
      );
    });

    test('detectedAt lùi về createdAt khi BE không trả', () {
      final e = WearableEvent.fromJson({
        'id': 'e',
        'eventType': 'FALL_DETECTED',
        'createdAt': '2026-08-06T09:00:00.000Z',
      });
      expect(e.detectedAt, isNotNull);
    });
  });

  group('WearableEventResult — kết quả gửi sự kiện', () {
    test('alertCreated=true thì đọc được alertId để điều hướng', () {
      final r = WearableEventResult.fromJson({
        'event': {'id': 'e1', 'eventType': 'SOS_BUTTON_PRESSED'},
        'alertId': 'alert-1',
        'alertCreated': true,
      });
      expect(r.alertCreated, isTrue);
      expect(r.alertId, 'alert-1');
      expect(r.event, isNotNull);
    });

    test(
      'alertCreated=false là hợp lệ — không phải sự kiện nào cũng báo động',
      () {
        final r = WearableEventResult.fromJson({
          'event': {'id': 'e1', 'eventType': 'ABNORMAL_MOVEMENT'},
          'alertId': null,
          'alertCreated': false,
        });
        expect(r.alertCreated, isFalse);
        expect(r.alertId, isNull);
      },
    );

    test('thiếu alertCreated thì hiểu là KHÔNG tạo cảnh báo', () {
      // Fail-safe: không được tự nhận là đã báo động cho cả nhà khi BE im lặng.
      expect(WearableEventResult.fromJson({}).alertCreated, isFalse);
    });
  });
}
