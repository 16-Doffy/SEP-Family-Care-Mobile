import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/money_request.dart';

class MoneyProvider extends ChangeNotifier {
  List<MoneyRequest> _requests = [];
  bool _loading = false;
  String? _error;

  List<MoneyRequest> get requests => _requests;
  List<MoneyRequest> get pendingRequests =>
      _requests.where((r) => r.status == MoneyRequestStatus.pending).toList();
  bool get isLoading => _loading;
  String? get error => _error;

  // UC34 — Lấy danh sách yêu cầu: GET /families/{familyId}/finance/support-requests
  Future<void> fetchRequests() async {
    if (ApiClient.instance.familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        ApiClient.instance.familyPath('/finance/support-requests'),
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

  // UC34 — Tạo yêu cầu: POST /families/{familyId}/finance/support-requests
  // CreateSpendingSupportRequestDto: { amount, categoryId?, purpose }
  Future<void> addRequest(MoneyRequest request) async {
    if (ApiClient.instance.familyId == null) {
      // Fallback offline nếu chưa có familyId
      _requests.insert(0, request);
      notifyListeners();
      return;
    }
    await ApiClient.instance.post(
      ApiClient.instance.familyPath('/finance/support-requests'),
      {
        'amount':  request.amount,
        'purpose': request.reason,
      },
    );
    await fetchRequests();
  }

  // UC35 — Duyệt/từ chối: PATCH .../support-requests/{id}/review
  // ReviewSpendingSupportRequestDto: { decision: APPROVE|REJECT, decisionNote?, occurredAt? }
  // (verify qua Swagger 2026-06-26 — KHÔNG có "D" cuối như comment cũ ghi nhầm,
  // gửi 'APPROVED'/'REJECTED' bị BE trả 400 "Quyết định duyệt không hợp lệ")
  Future<void> updateStatus(String requestId, MoneyRequestStatus status) async {
    if (ApiClient.instance.familyId == null) {
      // Fallback local
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _requests[idx].status = status;
        notifyListeners();
      }
      return;
    }
    final decision = status == MoneyRequestStatus.approved ? 'APPROVE' : 'REJECT';
    await ApiClient.instance.patch(
      ApiClient.instance.familyPath('/finance/support-requests/$requestId/review'),
      {
        'decision':    decision,
        'occurredAt': ApiClient.localIsoMs(),
      },
    );
    await fetchRequests();
  }

  // UC35 — Huỷ yêu cầu (bởi người tạo): PATCH .../support-requests/{id}/cancel
  Future<void> cancelRequest(String requestId) async {
    await ApiClient.instance.patch(
      ApiClient.instance.familyPath('/finance/support-requests/$requestId/cancel'),
      {},
    );
    await fetchRequests();
  }
}
