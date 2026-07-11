import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

/// Chat nhóm gia đình — nối API thật (BE bổ sung module chat 2026-07-11).
/// Nhóm mặc định do BE tự tạo cho mỗi gia đình; polling 5s khi màn đang mở.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  ChatProvider? _chat; // cache để dispose không phải lookup context

  static const _avatarColors = [
    AppColors.avatarBlue,
    AppColors.avatarPurple,
    AppColors.avatarOrange,
    AppColors.avatarTeal,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chat = context.read<ChatProvider>();
      _chat!.openDefaultConversation();
      _chat!.startPolling();
    });
  }

  @override
  void dispose() {
    // Rời màn chat thì ngừng polling — đỡ tốn request nền
    _chat?.stopPolling();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    try {
      await context.read<ChatProvider>().sendMessage(text);
      // reverse list: mới nhất ở offset 0 → cuộn về 0 là thấy tin vừa gửi
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gửi thất bại: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Color _colorFor(String memberId) =>
      _avatarColors[memberId.hashCode.abs() % _avatarColors.length];

  static String _fmtTime(DateTime? d) {
    if (d == null) return '';
    two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay ? '${two(d.hour)}:${two(d.minute)}' : '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final myUserId = context.watch<AuthProvider>().user?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Row(children: [
          const Text('👨‍👩‍👧', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(chat.conversationName,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ]),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => chat.fetchMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Expanded(child: _buildBody(chat, myUserId)),
          // Input bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _inputCtrl,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                          hintText: 'Nhắn tin...',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                          isDense: true,
                          contentPadding: EdgeInsets.zero),
                      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: chat.sending ? null : _send,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: chat.sending ? AppColors.textMuted : AppColors.link),
                    alignment: Alignment.center,
                    child: chat.sending
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ChatProvider chat, String myUserId) {
    if (chat.loading && chat.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chat.error != null && chat.messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Không tải được tin nhắn',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.danger)),
          const SizedBox(height: 8),
          ElevatedButton(
              onPressed: () => chat.openDefaultConversation(),
              child: const Text('Thử lại')),
        ]),
      );
    }
    if (chat.messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💬', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text('Chưa có tin nhắn nào',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('Gửi lời chào cho cả nhà đi!',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
    }

    // reverse: true — index 0 (tin mới nhất, BE trả DESC) nằm dưới đáy
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: chat.messages.length,
      itemBuilder: (_, i) {
        final m = chat.messages[i];
        final isMe = m.senderUserId == myUserId;
        // Tin liền kề cùng người gửi (m ở dưới, i+1 là tin ngay TRƯỚC nó) →
        // ẩn tên/avatar lặp lại cho gọn
        final prev = i + 1 < chat.messages.length ? chat.messages[i + 1] : null;
        final showSender = !isMe && (prev == null || prev.senderMemberId != m.senderMemberId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                if (showSender)
                  AvatarWidget(
                      initial: m.senderName.isNotEmpty
                          ? m.senderName.trim().split(' ').last.substring(0, 1).toUpperCase()
                          : '?',
                      color: _colorFor(m.senderMemberId),
                      size: 32)
                else
                  const SizedBox(width: 32),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (showSender)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2, left: 4),
                        child: Text(m.senderName,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted)),
                      ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.link : AppColors.white,
                        borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18)),
                        boxShadow: isMe
                            ? []
                            : [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ],
                      ),
                      child: Text(
                        m.isDeleted ? 'Tin nhắn đã thu hồi' : m.content,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontStyle: m.isDeleted ? FontStyle.italic : FontStyle.normal,
                          color: m.isDeleted
                              ? (isMe ? Colors.white70 : AppColors.textMuted)
                              : (isMe ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                      child: Text(_fmtTime(m.sentAt),
                          style:
                              GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
