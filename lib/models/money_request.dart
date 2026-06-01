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
}
