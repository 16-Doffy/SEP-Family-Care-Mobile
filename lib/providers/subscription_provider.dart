import 'package:flutter/foundation.dart';

import '../models/feature_access.dart';
import '../services/api_client.dart';

/// Nguồn sự thật duy nhất cho `featureAccess` của gia đình đang hoạt động.
///
/// Trước đây `AiChatbotProvider`, `AlbumProvider`, `AlbumFaceProvider` và
/// `CalendarProvider` mỗi cái tự gọi `GET /families/{id}/subscription` và tự
/// cache một bản [FeatureAccess] riêng — 4 request giống hệt nhau cho cùng
/// một dữ liệu, và thêm feature key mới phải sửa 4 chỗ y hệt nhau. Gom về
/// đây, gọi đúng 1 lần ở `family_shell` khi vào gia đình; 4 provider trên đọc
/// qua provider này thay vì tự fetch (xem `resetForNewSession`).
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  FeatureAccess? _featureAccess;
  bool _loading = false;

  /// Xóa dữ liệu của tài khoản vừa đăng xuất — provider này sống ở app scope
  /// (đăng ký trong `main.dart`) nên không bị hủy khi đổi tài khoản.
  void resetForNewSession() {
    _featureAccess = null;
    _loading = false;
    notifyListeners();
  }

  bool get loading => _loading;

  /// BE chưa trả lời, hoặc trả `featureAccess` rỗng → coi như KHÔNG BIẾT.
  ///
  /// Phải phân biệt với "đã trả lời và quyền = false": map rỗng mà coi là
  /// không-có-quyền thì gating fail-CLOSED, chặn cả tính năng gói Free vốn
  /// được dùng. Mọi getter `canX` dưới đây fail-open khi `isUnknown`, để BE
  /// tự chặn bằng 403 nếu thật sự sai quyền.
  bool get isUnknown => _featureAccess == null || _featureAccess!.isUnknown;

  bool has(String key, {List<String> aliases = const []}) =>
      isUnknown || _featureAccess!.flag(key, aliases: aliases);

  bool get canUseAssistant => isUnknown || _featureAccess!.aiAssistant;
  bool get canUploadVideo => isUnknown || _featureAccess!.albumVideoUpload;
  bool get canUseFaceSuggestions =>
      isUnknown || _featureAccess!.albumFaceSuggestions;
  bool get canCreateEvents => isUnknown || _featureAccess!.calendarEnabled;
  bool get canUseReminders => isUnknown || _featureAccess!.calendarReminders;
  bool get canUseRecurring =>
      isUnknown || _featureAccess!.calendarRecurringEvents;

  Future<void> fetch() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$fid/subscription');
      final plan = data is Map && data['plan'] is Map
          ? Map<String, dynamic>.from(data['plan'] as Map)
          : const <String, dynamic>{};
      final access = data is Map
          ? data['featureAccess'] ?? plan['featureAccess']
          : plan['featureAccess'];
      _featureAccess = FeatureAccess.fromJson(access);
      // flag() trả false cả khi key không tồn tại, nên "gói không có quyền"
      // và "FE gõ sai tên key" nhìn giống hệt nhau nếu không log raw ra đây.
      debugPrint(
        'SubscriptionProvider: featureAccess=${_featureAccess!.raw} '
        '(unknown=${_featureAccess!.isUnknown})',
      );
    } catch (e) {
      // Không đọc được gói thì giữ trạng thái "không biết" và fail-open.
      debugPrint('SubscriptionProvider: fetch failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
