import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../wear_widgets.dart';

class WearQuickMessageScreen extends StatefulWidget {
  const WearQuickMessageScreen({super.key});

  @override
  State<WearQuickMessageScreen> createState() => _WearQuickMessageScreenState();
}

class _WearQuickMessageScreenState extends State<WearQuickMessageScreen> {
  static const _presets = <String>[
    'Đang về nhà',
    'Đã đến nơi',
    'Con ổn',
    'Gọi con nhé',
    'Về trễ một chút',
  ];

  bool _sending = false;
  String? _sentText;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDefaultChat());
  }

  Future<void> _openDefaultChat() async {
    final chat = context.read<ChatProvider>();
    if (chat.conversationId != null) {
      await chat.fetchMessages();
      return;
    }
    await chat.openDefaultConversation();
    chat.startPolling();
  }

  Future<void> _send(String text) async {
    final chat = context.read<ChatProvider>();
    setState(() {
      _sending = true;
      _error = null;
    });
    HapticFeedback.lightImpact();

    try {
      if (chat.conversationId == null) {
        await chat.fetchConversations();
        if (chat.conversations.isNotEmpty) {
          await chat.openConversation(chat.conversations.first);
        }
      }
      if (chat.conversationId == null) {
        throw Exception('Chưa có hội thoại');
      }
      await chat.sendMessage(text);
      if (mounted) {
        setState(() {
          _sentText = text;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final myUserId = context.watch<AuthProvider>().user?.id ?? '';
    final recentMessages = chat.messages.where((m) => !m.isDeleted).take(4);

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearHeader(
            icon: Icons.message_rounded,
            label: 'Tin nhắn',
            color: WearPalette.green,
            trailing: _sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WearPalette.green,
                    ),
                  )
                : _sentText == null
                ? null
                : const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: WearPalette.green,
                  ),
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFFFCA5A5)),
            ),
            const SizedBox(height: 6),
          ],
          const WearSectionLabel('Tin mới'),
          if (chat.loading && chat.messages.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: WearEmptyState(
                icon: Icons.hourglass_top_rounded,
                title: 'Đang tải tin nhắn',
                color: WearPalette.green,
              ),
            )
          else if (recentMessages.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: WearEmptyState(
                icon: Icons.mark_chat_unread_rounded,
                title: 'Chưa có tin nhắn',
                subtitle: 'Tin mới sẽ hiện ở đây',
                color: WearPalette.faint,
              ),
            )
          else
            ...recentMessages.map((message) {
              final mine =
                  message.senderUserId.isNotEmpty &&
                  message.senderUserId == myUserId;
              final sender = mine
                  ? 'Bạn'
                  : (message.senderName.isEmpty
                        ? 'Thành viên'
                        : message.senderName);
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: WearTile(
                  icon: mine
                      ? Icons.north_east_rounded
                      : Icons.south_west_rounded,
                  title: sender,
                  subtitle: message.content.isEmpty
                      ? _messageTypeLabel(message.messageType)
                      : message.content,
                  color: mine ? WearPalette.blue : WearPalette.green,
                  filled: !mine,
                ),
              );
            }),
          const SizedBox(height: 4),
          const WearSectionLabel('Trả lời nhanh'),
          ..._presets.map((text) {
            final sent = _sentText == text;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: WearTile(
                icon: sent ? Icons.done_rounded : Icons.send_rounded,
                title: text,
                subtitle: sent ? 'Đã gửi' : 'Chạm để gửi',
                color: sent ? WearPalette.green : WearPalette.blue,
                filled: sent,
                onTap: _sending ? null : () => _send(text),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _messageTypeLabel(String type) {
    return switch (type) {
      'IMAGE' => 'Hình ảnh',
      'FILE' => 'Tệp đính kèm',
      'LOCATION' => 'Vị trí',
      'SOS_QUICK_MESSAGE' => 'Tin SOS',
      _ => 'Tin nhắn',
    };
  }
}
