enum MoneyRequestStatus { pending, approved, rejected, canceled }

class MoneyRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatarInitial;
  final int senderAvatarColor;
  final double amount;
  final String reason;
  final DateTime createdAt;
  MoneyRequestStatus status;

  MoneyRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarInitial,
    required this.senderAvatarColor,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.status = MoneyRequestStatus.pending,
  });

  // Maps BE SupportRequest schema
  factory MoneyRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requesterMember'] as Map<String, dynamic>?;
    final user      = requester?['user'] as Map<String, dynamic>?;
    final senderName = requester?['displayName'] as String? ??
        user?['fullName'] as String? ??
        'Thành viên';
    final senderId  = requester?['id']?.toString() ?? '';

    final statusStr = (json['status'] as String? ?? '').toUpperCase();
    final status = switch (statusStr) {
      'APPROVED' => MoneyRequestStatus.approved,
      'REJECTED' => MoneyRequestStatus.rejected,
      'CANCELED' => MoneyRequestStatus.canceled,
      _          => MoneyRequestStatus.pending,
    };

    final raw = json['amount'];
    final amount = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;

    return MoneyRequest(
      id: json['id']?.toString() ?? '',
      senderId: senderId,
      senderName: senderName,
      senderAvatarInitial: senderName.isNotEmpty
          ? senderName[0].toUpperCase()
          : '?',
      senderAvatarColor: 0xFF9333EA,
      amount: amount,
      reason: json['purpose'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      status: status,
    );
  }
}
