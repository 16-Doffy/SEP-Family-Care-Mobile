import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../wear_utils.dart';

/// Tin nhắn nhanh — CHỈ GỬI, không có ô nhập và không trả lời.
///
/// Cố ý bỏ khung chat: gõ phím trên đồng hồ là trải nghiệm tệ, và đọc hội thoại
/// dài trên màn tròn cũng không dùng được. Ở đây chỉ có vài câu dựng sẵn để báo
/// nhanh về nhóm gia đình; muốn trò chuyện thì mở điện thoại.
class WearQuickMessageScreen extends StatefulWidget {
  const WearQuickMessageScreen({super.key});

  @override
  State<WearQuickMessageScreen> createState() => _WearQuickMessageScreenState();
}

class _WearQuickMessageScreenState extends State<WearQuickMessageScreen> {
  static const _presets = <String>[
    'Con dang tren duong ve',
    'Con den noi roi',
    'Con on, dung lo',
    'Goi lai cho con nhe',
    'Con ve tre mot chut',
  ];

  bool _sending = false;
  String? _sentText;

  Future<void> _send(String text) async {
    final chat = context.read<ChatProvider>();
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      // Chưa mở hội thoại nào thì lấy nhóm chat chung (BE tự tạo/đồng bộ nhóm
      // này) làm đích mặc định — trên đồng hồ không có chỗ chọn hội thoại.
      if (chat.conversationId == null) {
        await chat.fetchConversations();
        if (chat.conversations.isNotEmpty) {
          await chat.openConversation(chat.conversations.first);
        }
      }
      if (chat.conversationId == null) {
        throw Exception('Chua co hoi thoai');
      }
      await chat.sendMessage(text);
      if (mounted) setState(() => _sentText = text);
    } catch (_) {
      if (mounted) setState(() => _sentText = null);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = WearUtils.safePadding(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding.left, 10, padding.right, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Nhan nhanh',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_sentText != null)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: Color(0xFF22C55E),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _presets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 5),
                  itemBuilder: (_, i) {
                    final text = _presets[i];
                    final justSent = _sentText == text;
                    return GestureDetector(
                      onTap: _sending ? null : () => _send(text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: justSent
                              ? const Color(0xFF14532D)
                              : const Color(0xFF171717),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
