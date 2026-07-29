import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

/// Tìm kiếm tin nhắn trong hội thoại đang mở — dùng `GET .../messages?q=`.
///
/// Kết quả chỉ hiển thị dạng danh sách, **không nhảy tới tin nhắn** trong khung
/// chat: tin tìm được có thể nằm ngoài 50 tin đang tải, muốn nhảy đúng chỗ phải
/// lật cursor tới đó rồi scroll-to-index — nằm ngoài phạm vi việc này.
class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key});

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<ChatMessage> _results = const [];
  bool _loading = false;
  String? _error;

  /// Từ khóa của lần tìm đã hiển thị — để phân biệt "chưa tìm gì" với
  /// "đã tìm nhưng không có kết quả".
  String _searchedFor = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searchedFor = '';
        _error = null;
        _loading = false;
      });
      return;
    }
    // Gõ tới đâu gọi tới đó sẽ bắn quá nhiều request → chờ người dùng dừng gõ.
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await context.read<ChatProvider>().searchMessages(query);
      if (!mounted) return;
      setState(() {
        _results = found.where((m) => !m.isDeleted).toList();
        _searchedFor = query;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _debounce?.cancel();
            if (v.trim().isNotEmpty) _search(v.trim());
          },
          style: GoogleFonts.inter(
            fontSize: 15,
            color: context.colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Tìm trong tin nhắn…',
            border: InputBorder.none,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              color: context.colors.textMuted,
            ),
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Xóa từ khóa',
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _hint(Icons.error_outline_rounded, _error!);
    }
    if (_searchedFor.isEmpty) {
      return _hint(
        Icons.search_rounded,
        'Nhập từ khóa để tìm trong hội thoại này.',
      );
    }
    if (_results.isEmpty) {
      return _hint(
        Icons.inbox_outlined,
        'Không có tin nhắn nào khớp "$_searchedFor".',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.colors.divider),
      itemBuilder: (_, i) => _resultTile(_results[i]),
    );
  }

  Widget _resultTile(ChatMessage m) {
    final content = m.content.trim().isEmpty
        ? (m.attachments.isEmpty ? '(không có nội dung)' : '(tệp đính kèm)')
        : m.content.trim();
    return ListTile(
      title: Text(
        m.senderName.isEmpty ? 'Thành viên' : m.senderName,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      ),
      subtitle: Text(
        content,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: context.colors.textSecondary,
        ),
      ),
      trailing: Text(
        _fmtTime(m.sentAt),
        style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
      ),
    );
  }

  Widget _hint(IconData icon, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.colors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    ),
  );

  static String _fmtTime(DateTime? t) {
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}\n${two(t.hour)}:${two(t.minute)}';
  }
}
