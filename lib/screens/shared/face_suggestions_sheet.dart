import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/album_provider.dart';
import '../../theme/app_colors.dart';

class FaceSuggestionsSheet extends StatefulWidget {
  final String mediaId;
  const FaceSuggestionsSheet({super.key, required this.mediaId});

  @override
  State<FaceSuggestionsSheet> createState() => _FaceSuggestionsSheetState();
}

class _FaceSuggestionsSheetState extends State<FaceSuggestionsSheet> {
  late Future<List<FaceSuggestion>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<AlbumProvider>().fetchFaceSuggestions(
      widget.mediaId,
    );
  }

  void _reload() {
    setState(
      () => _future = context.read<AlbumProvider>().fetchFaceSuggestions(
        widget.mediaId,
      ),
    );
  }

  Future<void> _scan() async {
    setState(() => _busy = true);
    try {
      await context.read<AlbumProvider>().requestFaceScan(widget.mediaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã yêu cầu quét khuôn mặt. Hãy tải lại sau ít phút.',
            ),
          ),
        );
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve(FaceSuggestion suggestion, bool confirm) async {
    setState(() => _busy = true);
    try {
      final album = context.read<AlbumProvider>();
      if (confirm) {
        await album.confirmFaceSuggestion(widget.mediaId, suggestion.id);
      } else {
        await album.rejectFaceSuggestion(widget.mediaId, suggestion.id);
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUse = context.watch<AlbumProvider>().canUseFaceSuggestions;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.face_retouching_natural_rounded,
                  color: AppColors.primary500,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gợi ý khuôn mặt AI',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text(
              canUse
                  ? 'Chỉ khi xác nhận, hệ thống mới tạo tag chính thức.'
                  : 'Gói hiện tại chưa có quyền Face Suggestion.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canUse && !_busy ? _scan : null,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Quét khuôn mặt trong ảnh'),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<FaceSuggestion>>(
                future: _future,
                builder: (_, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Không tải được gợi ý: ${snapshot.error}',
                      style: GoogleFonts.inter(color: AppColors.danger),
                    );
                  }
                  final items = snapshot.data ?? const <FaceSuggestion>[];
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Chưa có gợi ý. Hãy quét ảnh sau khi Face Profile đã sẵn sàng.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final s = items[index];
                      final subtitle = [
                        if (s.confidence != null)
                          'Độ tin cậy ${(s.confidence! <= 1 ? s.confidence! * 100 : s.confidence!).toStringAsFixed(0)}%',
                        _statusLabel(s.status),
                      ].join(' · ');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.memberName),
                        subtitle: Text(subtitle),
                        trailing: s.status == FaceSuggestionStatus.pending
                            ? Wrap(
                                spacing: 2,
                                children: [
                                  IconButton(
                                    tooltip: 'Xác nhận',
                                    onPressed: _busy
                                        ? null
                                        : () => _resolve(s, true),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Từ chối',
                                    onPressed: _busy
                                        ? null
                                        : () => _resolve(s, false),
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(FaceSuggestionStatus status) => switch (status) {
    FaceSuggestionStatus.pending => 'Chờ xử lý',
    FaceSuggestionStatus.confirmed => 'Đã xác nhận',
    FaceSuggestionStatus.rejected => 'Đã từ chối',
    FaceSuggestionStatus.unknown => 'Không rõ',
  };
}
