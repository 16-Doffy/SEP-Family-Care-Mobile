import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/app_feature_icon.dart';
import '../../widgets/avatar_widget.dart';
import 'chat_shared_content_screen.dart';

/// Chat gia đình — gán ĐỦ 18 endpoints module chat của BE (2026-07-11):
/// nhóm mặc định + nhóm tùy chỉnh + chat 1-1, gửi text/ảnh, sửa/thu hồi,
/// reaction, ghim, quản lý thành viên nhóm, polling 5s.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  ChatProvider? _chat; // cache để dispose không phải lookup context
  bool _uploading = false;

  static const _avatarColors = [
    AppColors.avatarBlue,
    AppColors.avatarPurple,
    AppColors.avatarOrange,
    AppColors.avatarTeal,
  ];
  static const _quickEmojis = ['❤️', '👍', '😆', '😮', '😢'];

  // Tin an toàn nhanh — gửi với messageType SOS_QUICK_MESSAGE (BE hỗ trợ sẵn
  // trong enum SendMessageDto), bubble hiển thị nổi bật màu cam
  static const _safetyPresets = [
    '🛡️ Mình đã đến nơi an toàn',
    '🏠 Mình đang trên đường về nhà',
    '📞 Rảnh thì gọi lại cho mình nhé',
    '⚠️ Mình đang gặp chuyện, để ý điện thoại giúp mình',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chat = context.read<ChatProvider>();
      _chat!.openDefaultConversation();
      _chat!.startPolling();
      // danh sách thành viên cho tạo nhóm/chat 1-1
      context.read<FamilyProvider>().fetchMembers();
    });
  }

  @override
  void dispose() {
    _chat?.stopPolling();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _myUserId => context.read<AuthProvider>().user?.id ?? '';

  Color _colorFor(String memberId) =>
      _avatarColors[memberId.hashCode.abs() % _avatarColors.length];

  static String _fmtTime(DateTime? d) {
    if (d == null) return '';
    two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay
        ? '${two(d.hour)}:${two(d.minute)}'
        : '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _snackErr(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(e.toString().replaceFirst('Exception: ', '')),
      backgroundColor: AppColors.danger,
    ));
  }

  // ── Gửi tin ────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    try {
      await context.read<ChatProvider>().sendMessage(text);
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } catch (e) {
      _snackErr(e);
    }
  }

  // Chọn ảnh → upload → gửi kèm caption đang gõ (nếu có)
  Future<void> _pickAndSendImage() async {
    final chat = context.read<ChatProvider>();
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final attachment = await chat.uploadAttachment(img.path);
      if (attachment == null || attachment.fileUrl.isEmpty) {
        throw Exception('Tải ảnh lên thất bại');
      }
      final caption = _inputCtrl.text.trim();
      _inputCtrl.clear();
      await chat.sendMessage(caption, attachments: [attachment]);
    } catch (e) {
      _snackErr(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Sheet chọn tin an toàn mẫu → gửi ngay với messageType SOS_QUICK_MESSAGE
  void _showSafetySheet() {
    final chat = context.read<ChatProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.health_and_safety_rounded, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              Text('Tin an toàn nhanh',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
            Text('Gửi 1 chạm để báo tình trạng cho cả nhà',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            ..._safetyPresets.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s, style: GoogleFonts.inter(fontSize: 14)),
                  trailing: const Icon(Icons.send_rounded, size: 18, color: Color(0xFFD97706)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await chat.sendMessage(s, messageType: 'SOS_QUICK_MESSAGE');
                      if (_scrollCtrl.hasClients) {
                        _scrollCtrl.animateTo(0,
                            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                      }
                    } catch (e) {
                      _snackErr(e);
                    }
                  },
                )),
          ]),
        ),
      ),
    );
  }

  // ── Menu tin nhắn (long-press) ────────────────────────────────────────────

  void _showMessageMenu(ChatMessage m) {
    final chat = context.read<ChatProvider>();
    final isMe = m.senderUserId == _myUserId;
    final myEmojis = m.reactions.where((r) => r.userId == _myUserId).map((r) => r.emoji).toSet();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          // Hàng reaction nhanh — bấm emoji đã thả của mình để bỏ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _quickEmojis.map((e) {
              final mine = myEmojis.contains(e);
              return GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    mine ? await chat.unreact(m.id, e) : await chat.react(m.id, e);
                  } catch (err) {
                    _snackErr(err);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.primary50 : AppColors.background,
                    shape: BoxShape.circle,
                    border: mine ? Border.all(color: AppColors.primary500) : null,
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: Icon(m.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppColors.textSecondary),
            title: Text(m.isPinned ? 'Bỏ ghim' : 'Ghim tin nhắn',
                style: GoogleFonts.inter(fontSize: 14)),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                m.isPinned ? await chat.unpinMessage(m.id) : await chat.pinMessage(m.id);
              } catch (err) {
                _snackErr(err);
              }
            },
          ),
          if (isMe && !m.isDeleted) ...[
            if (m.messageType == 'TEXT')
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                title: Text('Sửa tin nhắn', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog(m);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: Text('Thu hồi tin nhắn',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await chat.deleteMessage(m.id);
                } catch (err) {
                  _snackErr(err);
                }
              },
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showEditDialog(ChatMessage m) {
    final ctrl = TextEditingController(text: m.content);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Sửa tin nhắn', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(controller: ctrl, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              final text = ctrl.text.trim();
              if (text.isEmpty || text == m.content) return;
              try {
                await context.read<ChatProvider>().editMessage(m.id, text);
              } catch (err) {
                _snackErr(err);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // ── Danh sách hội thoại + tạo mới ─────────────────────────────────────────

  void _showConversationsSheet() {
    final chat = context.read<ChatProvider>();
    chat.fetchConversations();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer<ChatProvider>(
        builder: (_, c, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hội thoại', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView(
                  shrinkWrap: true,
                  children: c.conversations.map((conv) {
                    final selected = conv.id == c.conversationId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _conversationIcon(
                        type: conv.type,
                        isDefault: conv.isDefault,
                      ),
                      title: Text(conv.displayName(_myUserId),
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      subtitle: conv.isArchived
                          ? Text('Đã lưu trữ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))
                          : null,
                      trailing: selected
                          ? const Icon(Icons.check_rounded, color: AppColors.primary500, size: 20)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await chat.openConversation(conv);
                      },
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const AppFeatureIcon(
                  icon: Icons.group_add_outlined,
                  color: AppColors.primary500,
                  size: 38,
                  iconSize: 20,
                  radius: 12,
                ),
                title: Text('Tạo nhóm mới', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateGroupSheet();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const AppFeatureIcon(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary500,
                  size: 38,
                  iconSize: 20,
                  radius: 12,
                ),
                title: Text('Nhắn riêng', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPickMemberSheet(
                    title: 'Nhắn riêng với...',
                    onPick: (memberId) async {
                      try {
                        await context.read<ChatProvider>().createPrivate(memberId);
                      } catch (e) {
                        _snackErr(e);
                      }
                    },
                  );
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showCreateGroupSheet() {
    final nameCtrl = TextEditingController();
    final selected = <String>{};
    final members = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.userId != _myUserId && m.status == 'ACTIVE')
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tạo nhóm trò chuyện', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Tên nhóm (VD: Hội bàn việc Tết)'),
            ),
            const SizedBox(height: 12),
            Text('Chọn thành viên', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                children: members.map((m) {
                  final on = selected.contains(m.id);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: on,
                    title: Text(m.name, style: GoogleFonts.inter(fontSize: 14)),
                    onChanged: (_) => setS(() => on ? selected.remove(m.id) : selected.add(m.id)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty || selected.isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await context.read<ChatProvider>().createGroup(name, selected.toList());
                  } catch (e) {
                    _snackErr(e);
                  }
                },
                child: const Text('Tạo nhóm'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showPickMemberSheet({required String title, required Future<void> Function(String memberId) onPick}) {
    final members = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.userId != _myUserId && m.status == 'ACTIVE')
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Chưa có thành viên nào khác trong gia đình',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              )
            else
              ...members.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarWidget(
                        initial: m.name.isNotEmpty ? m.name.trim().split(' ').last.substring(0, 1).toUpperCase() : '?',
                        color: _colorFor(m.id),
                        size: 34),
                    title: Text(m.name, style: GoogleFonts.inter(fontSize: 14)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await onPick(m.id);
                    },
                  )),
          ]),
        ),
      ),
    );
  }

  // ── Cài đặt nhóm hiện tại ─────────────────────────────────────────────────

  void _showConversationSettings() {
    final chat = context.read<ChatProvider>();
    final conv = chat.active;
    if (conv == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(conv.displayName(_myUserId),
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('${conv.participants.length} thành viên · ${conv.type == 'PRIVATE' ? 'Chat riêng' : 'Nhóm'}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            // Danh sách thành viên trong hội thoại
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: conv.participants
                    .map((p) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarWidget(
                              initial: p.name.isNotEmpty
                                  ? p.name.trim().split(' ').last.substring(0, 1).toUpperCase()
                                  : '?',
                              color: _colorFor(p.memberId),
                              size: 30),
                          title: Text(p.name, style: GoogleFonts.inter(fontSize: 13.5)),
                          // Nhóm tùy chỉnh: xóa thành viên (trừ chính mình)
                          trailing: (!conv.isDefault && conv.type == 'GROUP' && p.userId != _myUserId)
                              ? IconButton(
                                  icon: const Icon(Icons.person_remove_outlined,
                                      size: 18, color: AppColors.danger),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await chat.removeParticipant(p.memberId);
                                    } catch (e) {
                                      _snackErr(e);
                                    }
                                  },
                                )
                              : null,
                        ))
                    .toList(),
              ),
            ),
            if (!conv.isDefault && conv.type == 'GROUP') ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_add_alt_outlined, color: AppColors.primary500),
                title: Text('Thêm thành viên', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPickMemberSheet(
                    title: 'Thêm vào nhóm',
                    onPick: (memberId) async {
                      try {
                        await chat.addParticipants([memberId]);
                      } catch (e) {
                        _snackErr(e);
                      }
                    },
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.drive_file_rename_outline, color: AppColors.textSecondary),
                title: Text('Đổi tên nhóm', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(conv.name);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                title: Text('Rời nhóm', style: GoogleFonts.inter(fontSize: 14, color: AppColors.danger)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await chat.leaveConversation();
                  } catch (e) {
                    _snackErr(e);
                  }
                },
              ),
            ],
          ]),
        ),
      ),
    );
  }

  void _showRenameDialog(String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Đổi tên nhóm', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              try {
                await context.read<ChatProvider>().updateConversation(name: ctrl.text.trim());
              } catch (e) {
                _snackErr(e);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showPinnedSheet() async {
    final chat = context.read<ChatProvider>();
    List<ChatMessage> pinned = [];
    try {
      pinned = await chat.fetchPinnedMessages();
    } catch (e) {
      _snackErr(e);
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const AppFeatureIcon(
                icon: Icons.push_pin_outlined,
                color: AppColors.primary500,
                size: 34,
                iconSize: 18,
                radius: 10,
              ),
              const SizedBox(width: 8),
              Text('Tin đã ghim (${pinned.length})',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            if (pinned.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Chưa có tin nào được ghim',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: pinned
                      .map((m) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.content.isNotEmpty ? m.content : '[Ảnh]',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 13.5)),
                            subtitle: Text('${m.senderName} · ${_fmtTime(m.sentAt)}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                          ))
                      .toList(),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final myUserId = context.watch<AuthProvider>().user?.id ?? '';
    final title = chat.active?.displayName(myUserId) ?? 'Gia đình';

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: _showConversationsSheet,
          child: Row(children: [
            _conversationIcon(
              type: chat.active?.type ?? 'GROUP',
              isDefault: chat.active?.isDefault ?? true,
              size: 34,
              iconSize: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
          ]),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Nội dung đã chia sẻ',
            icon: const Icon(Icons.perm_media_outlined, color: AppColors.textMuted, size: 21),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatSharedContentScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.push_pin_outlined, color: AppColors.textMuted, size: 21),
            onPressed: _showPinnedSheet,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
            onPressed: _showConversationSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Expanded(child: _buildBody(chat, myUserId)),
          _inputBar(chat),
        ],
      ),
    );
  }

  Widget _inputBar(ChatProvider chat) {
    final archived = chat.active?.isArchived == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
          color: AppColors.white, border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
      child: archived
          ? Center(
              child: Text('Nhóm đã lưu trữ — không thể gửi tin',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)))
          : Row(
              children: [
                GestureDetector(
                  onTap: _uploading ? null : _pickAndSendImage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration:
                        const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3F4F6)),
                    alignment: Alignment.center,
                    child: _uploading
                        ? const SizedBox.square(
                            dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_outlined, size: 20, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showSafetySheet,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFFFFF7ED)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.health_and_safety_outlined,
                        size: 20, color: Color(0xFFD97706)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
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
    );
  }

  Widget _conversationIcon({
    required String type,
    required bool isDefault,
    double size = 40,
    double iconSize = 21,
  }) {
    final isPrivate = type == 'PRIVATE';
    return AppFeatureIcon(
      icon: isPrivate
          ? Icons.chat_bubble_outline_rounded
          : isDefault
              ? Icons.family_restroom_rounded
              : Icons.groups_2_outlined,
      color: isPrivate ? AppColors.primary500 : AppColors.link,
      size: size,
      iconSize: iconSize,
      radius: 12,
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
              onPressed: () => chat.openDefaultConversation(), child: const Text('Thử lại')),
        ]),
      );
    }
    if (chat.messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppFeatureIcon(
            icon: Icons.chat_bubble_outline_rounded,
            color: AppColors.primary500,
            size: 64,
            iconSize: 32,
            radius: 20,
          ),
          const SizedBox(height: 10),
          Text('Chưa có tin nhắn nào',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('Gửi lời chào cho cả nhà đi!',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: chat.messages.length,
      itemBuilder: (_, i) {
        final m = chat.messages[i];
        final isMe = m.senderUserId == myUserId;
        final prev = i + 1 < chat.messages.length ? chat.messages[i + 1] : null;
        final showSender = !isMe && (prev == null || prev.senderMemberId != m.senderMemberId);
        return _bubble(m, isMe, showSender);
      },
    );
  }

  Widget _bubble(ChatMessage m, bool isMe, bool showSender) {
    // Tin an toàn nhanh: bubble cam nổi bật, chữ tối dù là tin của mình
    final isSos = m.messageType == 'SOS_QUICK_MESSAGE' && !m.isDeleted;
    // Gộp reaction theo emoji: {❤️: 2, 👍: 1}
    final reactionCounts = <String, int>{};
    for (final r in m.reactions) {
      reactionCounts[r.emoji] = (reactionCounts[r.emoji] ?? 0) + 1;
    }
    final myEmojis = m.reactions.where((r) => r.userId == _myUserId).map((r) => r.emoji).toSet();

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
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(m.senderName,
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ),
                GestureDetector(
                  onLongPress: m.isDeleted ? null : () => _showMessageMenu(m),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSos
                          ? const Color(0xFFFFF7ED)
                          : (isMe ? AppColors.link : AppColors.white),
                      border: isSos ? Border.all(color: const Color(0xFFF59E0B)) : null,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSos)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.health_and_safety_rounded,
                                  size: 13, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text('TIN AN TOÀN',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: .5,
                                      color: const Color(0xFFD97706))),
                            ]),
                          ),
                        // Ảnh đính kèm
                        if (!m.isDeleted)
                          ...m.attachments.where((a) => a.isImage).map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    a.fileUrl,
                                    width: 220,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, p) => p == null
                                        ? child
                                        : Container(
                                            width: 220,
                                            height: 140,
                                            color: AppColors.background,
                                            alignment: Alignment.center,
                                            child: const CircularProgressIndicator(strokeWidth: 2)),
                                    errorBuilder: (_, _, _) => Container(
                                        width: 220,
                                        height: 80,
                                        color: AppColors.background,
                                        alignment: Alignment.center,
                                        child: Text('Không tải được ảnh',
                                            style: GoogleFonts.inter(
                                                fontSize: 12, color: AppColors.textMuted))),
                                  ),
                                ),
                              )),
                        if (m.isDeleted || m.content.isNotEmpty)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (m.isPinned && !m.isDeleted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.push_pin,
                                    size: 12,
                                    color: isMe && !isSos ? Colors.white70 : AppColors.textMuted),
                              ),
                            Flexible(
                              child: Text(
                                m.isDeleted ? 'Tin nhắn đã thu hồi' : m.content,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontStyle: m.isDeleted ? FontStyle.italic : FontStyle.normal,
                                  color: m.isDeleted
                                      ? (isMe ? Colors.white70 : AppColors.textMuted)
                                      : (isMe && !isSos ? Colors.white : AppColors.textPrimary),
                                ),
                              ),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
                // Reaction chips
                if (reactionCounts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Wrap(
                      spacing: 4,
                      children: reactionCounts.entries.map((e) {
                        final mine = myEmojis.contains(e.key);
                        return GestureDetector(
                          onTap: () async {
                            final chat = context.read<ChatProvider>();
                            try {
                              mine
                                  ? await chat.unreact(m.id, e.key)
                                  : await chat.react(m.id, e.key);
                            } catch (err) {
                              _snackErr(err);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: mine ? AppColors.primary50 : AppColors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: mine ? AppColors.primary500 : const Color(0xFFE5E7EB)),
                            ),
                            child: Text('${e.key} ${e.value}',
                                style: GoogleFonts.inter(fontSize: 11.5)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_fmtTime(m.sentAt),
                        style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
                    if (m.isEdited && !m.isDeleted)
                      Text(' · đã sửa',
                          style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
