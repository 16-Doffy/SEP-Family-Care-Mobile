import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/ai_chatbot.dart';
import '../../providers/ai_chatbot_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/ai_chatbot_icon.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AiChatbotProvider>().bootstrap();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await context.read<AiChatbotProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiChatbotProvider>(
      builder: (context, ai, _) {
        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            backgroundColor: context.colors.surface,
            elevation: 0,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: context.colors.textPrimary,
              ),
            ),
            title: Row(
              children: [
                const AiChatbotIcon(size: 30),
                const SizedBox(width: 8),
                Text(
                  'Trợ lý AI',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Hội thoại',
                onPressed: () => _showConversationSheet(context),
                icon: Icon(
                  Icons.forum_outlined,
                  color: context.colors.textPrimary,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: context.colors.textPrimary,
                ),
                onSelected: (value) {
                  if (value == 'new') {
                    context.read<AiChatbotProvider>().startNewConversation();
                  } else if (value == 'delete') {
                    _confirmDeleteConversation(context);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'new',
                    child: Text('Hội thoại mới'),
                  ),
                  if (ai.currentConversationId != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa hội thoại này'),
                    ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Divider(height: 1, color: context.colors.divider),
              if (ai.error != null) _ErrorBanner(message: ai.error!),
              Expanded(child: _MessageList(scrollCtrl: _scrollCtrl)),
              _QuickPrompts(onPick: (prompt) {
                _inputCtrl.text = prompt;
                _send();
              }),
              _Composer(
                controller: _inputCtrl,
                sending: ai.sending,
                onSend: _send,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConversationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (sheetContext) {
        return Consumer<AiChatbotProvider>(
          builder: (context, ai, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hội thoại AI',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add_comment_outlined),
                      title: const Text('Tạo hội thoại mới'),
                      onTap: () {
                        ai.startNewConversation();
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                    Flexible(
                      child: ai.loadingConversations
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: ai.conversations.length,
                              itemBuilder: (_, i) {
                                final c = ai.conversations[i];
                                final selected =
                                    c.id == ai.currentConversationId;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    color: selected
                                        ? AppColors.primary500
                                        : context.colors.textMuted,
                                  ),
                                  title: Text(
                                    c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: c.lastMessage == null ||
                                          c.lastMessage!.isEmpty
                                      ? null
                                      : Text(
                                          c.lastMessage!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  onTap: () {
                                    ai.selectConversation(c.id);
                                    Navigator.of(sheetContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteConversation(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa hội thoại?'),
        content: const Text('Toàn bộ tin nhắn trong hội thoại này sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AiChatbotProvider>().deleteCurrentConversation();
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scrollCtrl;

  const _MessageList({required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiChatbotProvider>();
    if (ai.loadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }
    final messages = ai.messages;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AiChatbotIcon(size: 72),
              const SizedBox(height: 14),
              Text(
                'Xin chào, tôi là trợ lý FamilyCare.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn có thể hỏi về chi tiêu, nhiệm vụ, lịch gia đình hoặc nhờ tôi tạo đề xuất để xác nhận.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (ai.sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= messages.length) return const _TypingBubble();
        return _MessageBubble(message: messages[i]);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isUser;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.link : context.colors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.35,
              color: isMe ? Colors.white : context.colors.textPrimary,
            ),
          ),
          if (message.pendingAction != null) ...[
            const SizedBox(height: 12),
            _PendingActionCard(
              messageId: message.id,
              action: message.pendingAction!,
            ),
          ],
        ],
      ),
    );
    if (isMe) return Align(alignment: Alignment.centerRight, child: bubble);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 8),
          child: AiChatbotIcon(size: 28),
        ),
        Flexible(child: bubble),
      ],
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  final String messageId;
  final AiPendingAction action;

  const _PendingActionCard({required this.messageId, required this.action});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiChatbotProvider>();
    final busy = ai.isActionBusy(messageId);
    final enabled = action.isPending && !busy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: AppColors.primary600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.actionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary600,
                  ),
                ),
              ),
            ],
          ),
          if (action.preview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _previewText(action.preview),
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!action.isPending)
            Text(
              'Đề xuất đã hết hạn hoặc đã được xử lý.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled
                        ? () => context
                            .read<AiChatbotProvider>()
                            .rejectAction(messageId)
                        : null,
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: enabled
                        ? () => context
                            .read<AiChatbotProvider>()
                            .confirmAction(messageId)
                        : null,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Xác nhận'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _previewText(Map<String, dynamic> preview) {
    return preview.entries
        .take(6)
        .map((e) => '${_label(e.key)}: ${e.value}')
        .join('\n');
  }

  String _label(String key) => switch (key) {
        'amount' => 'Số tiền',
        'category' || 'categoryName' => 'Danh mục',
        'description' || 'note' => 'Ghi chú',
        'title' => 'Tiêu đề',
        'dueAt' || 'dueDate' => 'Hạn',
        _ => key,
      };
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 8),
          child: AiChatbotIcon(size: 28),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Đang trả lời...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _QuickPrompts({required this.onPick});

  @override
  Widget build(BuildContext context) {
    const prompts = [
      (label: 'Chi tiêu tháng này', prompt: 'Tháng này nhà mình tiêu hết bao nhiêu?'),
      (label: 'Tạo giao dịch', prompt: 'Ghi nhận khoản chi 200000 cho ăn uống hôm nay'),
      (label: 'Tình hình nhiệm vụ', prompt: 'Tóm tắt nhiệm vụ của gia đình'),
      (label: 'Lịch tuần này', prompt: 'Tuần này nhà mình có lịch gì?'),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: prompts.map((q) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(q.label),
              onPressed: () => onPick(q.prompt),
              backgroundColor: context.colors.surface,
              side: BorderSide(color: context.colors.divider),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!sending) onSend();
                },
                decoration: InputDecoration(
                  hintText: 'Hỏi về chi tiêu, nhiệm vụ...',
                  filled: true,
                  fillColor: context.colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: GoogleFonts.inter(color: context.colors.textMuted),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.arrow_upward_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.link,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.20)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.danger,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
