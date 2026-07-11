enum MoneyRequestStatus { pending, approved, rejected }

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

  // Mapping từ BE: CreateSpendingSupportRequestDto response
  // { id, amount, purpose, status: PENDING|APPROVED|REJECTED, requester: { id, fullName } }
  factory MoneyRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] is Map
        ? json['requester'] as Map<String, dynamic>
        : json['member'] is Map
            ? json['member'] as Map<String, dynamic>
            : <String, dynamic>{};
    final name  = requester['fullName']?.toString() ??
                  requester['displayName']?.toString() ?? 'Thành viên';
    final uid   = requester['id']?.toString() ?? '';
    final colors = [0xFF3B82F6, 0xFFA78BFA, 0xFFFB923C, 0xFF2DD4BF, 0xFFEC4899];
    final color  = colors[uid.hashCode.abs() % colors.length];

    final statusStr = (json['status'] as String? ?? '').toUpperCase();
    final status = statusStr == 'APPROVED'
        ? MoneyRequestStatus.approved
        : statusStr == 'REJECTED'
            ? MoneyRequestStatus.rejected
            : MoneyRequestStatus.pending;

    return MoneyRequest(
      id:                  json['id']?.toString() ?? '',
      senderId:            uid,
      senderName:          name,
      senderAvatarInitial: name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
      senderAvatarColor:   color,
      amount:              _d(json['amount']),
      reason:              json['purpose']?.toString() ?? json['reason']?.toString() ?? '',
      createdAt:           DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      status:              status,
    );
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
