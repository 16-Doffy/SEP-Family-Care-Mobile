import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class _Msg {
  final String id, sender, text, time;
  final Color senderColor;
  final bool isMe;
  const _Msg({required this.id, required this.sender, required this.senderColor, required this.text, required this.time, required this.isMe});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isGroup = true;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_Msg>[
    const _Msg(id:'1', sender:'Mẹ', senderColor:AppColors.avatarPurple, text:'Tối nay ăn lẩu nhé 🍲', time:'18:30', isMe:false),
    const _Msg(id:'2', sender:'Ba', senderColor:AppColors.avatarBlue, text:'Oke mẹ, 19h ba về đến', time:'18:32', isMe:true),
    const _Msg(id:'3', sender:'An', senderColor:AppColors.avatarOrange, text:'Con xong bài tập rồi! 🎉', time:'18:35', isMe:false),
    const _Msg(id:'4', sender:'Ba', senderColor:AppColors.avatarBlue, text:'Giỏi lắm An!', time:'18:36', isMe:true),
    const _Msg(id:'5', sender:'Bi', senderColor:AppColors.avatarTeal, text:'Mẹ mua thêm sữa nha mẹ 🥛', time:'18:40', isMe:false),
  ];

  void _send() {
    if (_inputCtrl.text.trim().isEmpty) return;
    final now = TimeOfDay.now();
    setState(() {
      _messages.add(_Msg(id: DateTime.now().millisecondsSinceEpoch.toString(), sender: 'Ba', senderColor: AppColors.avatarBlue, text: _inputCtrl.text.trim(), time: '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}', isMe: true));
      _inputCtrl.clear();
    });
    Future.delayed(const Duration(milliseconds: 100), () => _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: Row(children: [
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _isGroup = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _isGroup ? AppColors.link : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
              child: Text('👨‍👩‍👧 Nhóm', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _isGroup ? Colors.white : AppColors.textSecondary)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _isGroup = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: !_isGroup ? AppColors.link : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
              child: Text('💬 Riêng', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: !_isGroup ? Colors.white : AppColors.textSecondary)),
            ),
          ),
        ]),
        leadingWidth: 200,
        title: Text(_isGroup ? 'Gia đình Nguyễn' : 'Nhắn tin riêng', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: m.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!m.isMe) ...[AvatarWidget(initial: m.sender.substring(0, min(2, m.sender.length)), color: m.senderColor, size: 32), const SizedBox(width: 8)],
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                        child: Column(
                          crossAxisAlignment: m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!m.isMe) Padding(padding: const EdgeInsets.only(bottom: 2, left: 4), child: Text(m.sender, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: m.isMe ? AppColors.link : AppColors.white,
                                borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(m.isMe ? 18 : 4), bottomRight: Radius.circular(m.isMe ? 4 : 18)),
                                boxShadow: m.isMe ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Text(m.text, style: GoogleFonts.inter(fontSize: 15, color: m.isMe ? Colors.white : AppColors.textPrimary)),
                            ),
                            Padding(padding: const EdgeInsets.only(top: 4, left: 4, right: 4), child: Text(m.time, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
            child: Row(
              children: [
                Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3F4F6)), alignment: Alignment.center, child: const Text('📍', style: TextStyle(fontSize: 18))),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _inputCtrl,
                      maxLines: null,
                      decoration: InputDecoration(hintText: 'Nhắn tin...', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted), isDense: true, contentPadding: EdgeInsets.zero),
                      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.link), alignment: Alignment.center, child: const Text('↑', style: TextStyle(fontSize: 18, color: Colors.white))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;
}
