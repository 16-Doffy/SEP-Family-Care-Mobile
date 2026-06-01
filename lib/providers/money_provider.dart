import 'package:flutter/material.dart';
import '../models/money_request.dart';

class MoneyProvider extends ChangeNotifier {
  final List<MoneyRequest> _requests = [
    MoneyRequest(
      id: '1',
      senderId: 'child_1',
      senderName: 'An',
      senderAvatarInitial: 'AN',
      senderAvatarColor: 0xFFEA580C,
      amount: 50000,
      reason: 'Mua sách tham khảo Toán',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    MoneyRequest(
      id: '2',
      senderId: 'child_2',
      senderName: 'Bi',
      senderAvatarInitial: 'BI',
      senderAvatarColor: 0xFF9333EA,
      amount: 30000,
      reason: 'Tiền ăn sáng thứ 2',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  List<MoneyRequest> get requests => _requests;
  List<MoneyRequest> get pendingRequests => _requests.where((r) => r.status == MoneyRequestStatus.pending).toList();

  void addRequest(MoneyRequest request) {
    _requests.insert(0, request);
    notifyListeners();
  }

  void updateStatus(String requestId, MoneyRequestStatus status) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index].status = status;
      notifyListeners();
    }
  }
}
