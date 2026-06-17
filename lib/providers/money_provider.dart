import 'package:flutter/material.dart';
import '../models/money_request.dart';
import '../services/api_client.dart';

class MoneyProvider extends ChangeNotifier {
  String? _familyId;

  List<MoneyRequest> _requests = [];
  bool _loading = false;
  String? _error;

  List<MoneyRequest> get requests => _requests;
  bool get isLoading => _loading;
  String? get error => _error;

  List<MoneyRequest> get pendingRequests =>
      _requests.where((r) => r.status == MoneyRequestStatus.pending).toList();

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchRequests();
    }
  }

  Future<void> fetchRequests() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/families/$_familyId/finance/support-requests',
        params: {'limit': '50'},
      );
      final list = data is List
          ? data
          : data is Map && data['items'] is List
              ? data['items'] as List
              : <dynamic>[];
      _requests = list
          .whereType<Map>()
          .map((e) => MoneyRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Thành viên tạo yêu cầu hỗ trợ chi tiêu
  Future<void> addRequest({
    required double amount,
    required String purpose,
    String? categoryId,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/finance/support-requests',
      {
        'amount': amount,
        'purpose': purpose,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    await fetchRequests();
  }

  // Manager phê duyệt hoặc từ chối
  Future<void> reviewRequest(
    String requestId, {
    required bool approved,
    String? note,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/finance/support-requests/$requestId/review',
      {
        'decision': approved ? 'APPROVE' : 'REJECT',
        if (note != null && note.isNotEmpty) 'decisionNote': note,
      },
    );
    await fetchRequests();
  }

  // Thành viên hủy yêu cầu của mình
  Future<void> cancelRequest(String requestId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$_familyId/finance/support-requests/$requestId/cancel',
    );
    await fetchRequests();
  }

  // Giữ lại cho tương thích với wallet_screen (approve/reject nhanh)
  Future<void> updateStatus(String requestId, MoneyRequestStatus status) async {
    if (status == MoneyRequestStatus.approved) {
      await reviewRequest(requestId, approved: true);
    } else if (status == MoneyRequestStatus.rejected) {
      await reviewRequest(requestId, approved: false);
    } else if (status == MoneyRequestStatus.canceled) {
      await cancelRequest(requestId);
    }
  }
}
