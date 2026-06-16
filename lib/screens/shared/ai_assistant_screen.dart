import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});
  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _msgs = <({bool isMe, String text})>[
    (isMe: false, text: 'Xin chào! Tôi là trợ lý AI của FamilyCare 🤖\nBạn muốn hỏi gì về chi tiêu, tasks hoặc lịch gia đình?'),
  ];

  void _send() {
    if (_inputCtrl.text.trim().isEmpty) return;
    final q = _inputCtrl.text.trim();
    _inputCtrl.clear();
    setState(() {
      _msgs.add((isMe: true, text: q));
      _msgs.add((isMe: false, text: _autoReply(q)));
    });
    Future.delayed(const Duration(milliseconds: 100), () => _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
  }

  String _autoReply(String q) {
    if (q.toLowerCase().contains('chi')) return 'Tháng này bạn đã chi 35,000,000 ₫ — trong đó 20M chi chung và 15M chi riêng. Còn dư 15M (30% dự phòng) 💰';
    if (q.toLowerCase().contains('task') || q.toLowerCase().contains('việc')) return 'Hiện có 3/5 tasks hoàn thành. An đang chờ duyệt "Dọn phòng ngủ" — hãy xem nhé! ✅';
    if (q.toLowerCase().contains('tiết kiệm') || q.toLowerCase().contains('save')) return 'Để tiết kiệm hiệu quả:\n• Đặt mục tiêu 5M/tháng\n• Hạn chế ăn ngoài > 2 lần/tuần\n• Đặt reminder chi tiêu 💡';
    return 'Tôi hiểu câu hỏi của bạn! Hãy cụ thể hơn về chi tiêu, tasks hay lịch gia đình nhé 😊';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(onTap: () => context.pop(), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary)),
        title: Row(children: [const Text('🤖', style: TextStyle(fontSize: 24)), const SizedBox(width: 8), Text('Trợ lý AI', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                return Align(
                  alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: m.isMe ? AppColors.link : AppColors.white,
                      borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(m.isMe ? 18 : 4), bottomRight: Radius.circular(m.isMe ? 4 : 18)),
                      boxShadow: m.isMe ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Text(m.text, style: GoogleFonts.inter(fontSize: 15, color: m.isMe ? Colors.white : AppColors.textPrimary)),
                  ),
                );
              },
            ),
          ),

          // Quick suggestions
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['💰 Chi tiêu tháng này', '📋 Tình hình tasks', '💡 Mẹo tiết kiệm', '📅 Lịch tuần này'].map((q) =>
                GestureDetector(
                  onTap: () { _inputCtrl.text = q.substring(3); _send(); },
                  child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]), child: Text(q, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary))),
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                    child: TextField(controller: _inputCtrl, decoration: InputDecoration(hintText: 'Hỏi về chi tiêu, tasks...', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted), isDense: true, contentPadding: EdgeInsets.zero), style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary), onSubmitted: (_) => _send()),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(onTap: _send, child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.link), alignment: Alignment.center, child: const Text('↑', style: TextStyle(fontSize: 18, color: Colors.white)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
