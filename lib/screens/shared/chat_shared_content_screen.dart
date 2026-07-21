import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';

/// Xem lại ảnh / file / liên kết đã gửi trong hội thoại.
///
/// Dữ liệu lọc từ [ChatProvider.messages] — hiện là **50 tin gần nhất** vì API
/// GET messages không có filter theo type và không phân trang lùi (xem Swagger
/// tuần 10). Có ghi chú rõ giới hạn này trên UI để không gây hiểu nhầm là đã
/// tải toàn bộ lịch sử.
class ChatSharedContentScreen extends StatelessWidget {
  const ChatSharedContentScreen({super.key});

  static final _linkRegex = RegExp(r'(https?://[^\s]+)', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<ChatProvider>().messages;

    // Bỏ tin đã xóa. messages theo thứ tự DESC (mới nhất trước) — giữ nguyên để
    // nội dung mới hiện lên đầu.
    final visible = messages.where((m) => !m.isDeleted).toList();

    final images = <(ChatMessage, ChatAttachment)>[];
    final files = <(ChatMessage, ChatAttachment)>[];
    final links = <(ChatMessage, String)>[];

    for (final m in visible) {
      for (final a in m.attachments) {
        if (a.fileUrl.isEmpty) continue;
        (a.isImage ? images : files).add((m, a));
      }
      for (final match in _linkRegex.allMatches(m.content)) {
        links.add((m, match.group(0)!));
      }
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: Text(
            'Nội dung đã chia sẻ',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary500,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary500,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Ảnh & File (${images.length + files.length})'),
              Tab(text: 'Liên kết (${links.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.primary50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Hiển thị nội dung từ 50 tin nhắn gần nhất.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _MediaTab(images: images, files: files),
                  _LinksTab(links: links),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _snack(context, 'Không mở được liên kết');
  } catch (_) {
    if (context.mounted) _snack(context, 'Không mở được liên kết');
  }
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
  );
}

String _fmtTime(DateTime? t) {
  if (t == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

Widget _emptyState(String text) => Center(
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
        ),
      ],
    ),
  ),
);

class _MediaTab extends StatelessWidget {
  const _MediaTab({required this.images, required this.files});

  final List<(ChatMessage, ChatAttachment)> images;
  final List<(ChatMessage, ChatAttachment)> files;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty && files.isEmpty) {
      return _emptyState('Chưa có ảnh hoặc file nào được chia sẻ.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (images.isNotEmpty) ...[
          _sectionLabel('Ảnh (${images.length})'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: images.length,
            itemBuilder: (_, i) {
              final att = images[i].$2;
              return GestureDetector(
                onTap: () => _viewImage(context, att.fileUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    att.fileUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFE5E7EB),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        if (files.isNotEmpty) ...[
          _sectionLabel('File (${files.length})'),
          ...files.map((e) {
            final (msg, att) = e;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.primary500,
              ),
              title: Text(
                att.fileName ?? 'Tệp đính kèm',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 14),
              ),
              subtitle: Text(
                '${msg.senderName} · ${_fmtTime(msg.sentAt)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _openExternal(context, att.fileUrl),
            );
          }),
        ],
      ],
    );
  }

  static Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  void _viewImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  url,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinksTab extends StatelessWidget {
  const _LinksTab({required this.links});

  final List<(ChatMessage, String)> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return _emptyState('Chưa có liên kết nào được chia sẻ.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: links.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final (msg, url) = links[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.link_rounded, color: AppColors.primary500),
          title: Text(
            url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.link),
          ),
          subtitle: Text(
            '${msg.senderName} · ${_fmtTime(msg.sentAt)}',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
          ),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => _openExternal(context, url),
        );
      },
    );
  }
}
