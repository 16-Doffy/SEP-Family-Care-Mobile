import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/album_face_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';

/// Section "Người trong ảnh" trong màn chi tiết ảnh album.
///
/// Quét khuôn mặt → BE trả gợi ý thành viên → user Xác nhận (tạo tag chính
/// thức) hoặc Từ chối. Chỉ mở khi gói có `album.faceSuggestions`; chưa có quyền
/// thì hiện thông báo nâng cấp thay vì nút chết.
///
/// Chỉ áp dụng cho ảnh (không video) và media đã SAFE — tag chỉ gắn được cho
/// media SAFE theo hợp đồng BE.
class AlbumFaceSection extends StatefulWidget {
  const AlbumFaceSection({
    super.key,
    required this.mediaId,
    required this.isImage,
    required this.isSafe,
    required this.hasRecognizedTag,
  });

  final String mediaId;
  final bool isImage;
  final bool isSafe;
  final bool hasRecognizedTag;

  @override
  State<AlbumFaceSection> createState() => _AlbumFaceSectionState();
}

class _AlbumFaceSectionState extends State<AlbumFaceSection> {
  FaceScanState _scan = FaceScanState.notScanned;
  List<FaceSuggestion> _suggestions = const [];
  bool _loading = true;
  bool _busy = false;

  AlbumFaceProvider get _face => context.read<AlbumFaceProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!widget.isImage) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _face.fetchFeatureAccess();
    if (!_face.canUseFaceSuggestions) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      var scan = await _face.fetchScanStatus(widget.mediaId);
      var sug = await _face.fetchSuggestions(widget.mediaId);

      if (_shouldAutoScan(scan, sug)) {
        try {
          await _face.requestScan(widget.mediaId);
          await Future.delayed(const Duration(seconds: 2));
          scan = await _face.fetchScanStatus(widget.mediaId);
          sug = await _face.fetchSuggestions(widget.mediaId);
        } catch (_) {
          // Keep the manual scan button available if the priority scan fails.
        }
      }

      if (!mounted) return;
      setState(() {
        _scan = sug.isNotEmpty ? FaceScanState.hasSuggestions : scan;
        _suggestions = sug;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _shouldAutoScan(FaceScanState scan, List<FaceSuggestion> suggestions) {
    return widget.isSafe &&
        !widget.hasRecognizedTag &&
        suggestions.isEmpty &&
        scan == FaceScanState.notScanned;
  }

  Future<void> _scanNow() async {
    setState(() => _busy = true);
    try {
      await _face.requestScan(widget.mediaId, force: true);
      // Quét chạy nền (202). Đợi một nhịp rồi lấy trạng thái + gợi ý.
      await Future.delayed(const Duration(seconds: 2));
      final scan = await _face.fetchScanStatus(widget.mediaId);
      final sug = await _face.fetchSuggestions(widget.mediaId);
      if (!mounted) return;
      setState(() {
        _scan = sug.isNotEmpty ? FaceScanState.hasSuggestions : scan;
        _suggestions = sug;
      });
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve(FaceSuggestion s, {required bool confirm}) async {
    setState(() => _busy = true);
    try {
      if (confirm) {
        await _face.confirmSuggestion(widget.mediaId, s.id);
      } else {
        await _face.rejectSuggestion(widget.mediaId, s.id);
      }
      // Bỏ gợi ý vừa xử lý khỏi danh sách chờ.
      setState(
        () => _suggestions = _suggestions.where((e) => e.id != s.id).toList(),
      );
      _snack(confirm ? 'Đã xác nhận và gắn thẻ' : 'Đã bỏ qua gợi ý', ok: true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }

  String _memberName(String id) {
    final members = context.read<FamilyProvider>().members;
    for (final m in members) {
      if (m.id == id) return m.name.isEmpty ? 'Thành viên' : m.name;
    }
    return 'Thành viên';
  }

  String _confidenceLabel(double? c) {
    if (c == null) return '';
    final pct = c <= 1 ? c * 100 : c;
    return '${pct.round()}%';
  }

  ({String text, Color color}) get _statusChip => switch (_scan) {
    FaceScanState.processing => (text: 'Đang quét…', color: AppColors.link),
    FaceScanState.scanned => (text: 'Đã quét', color: AppColors.success),
    FaceScanState.noFace => (
      text: 'Không phát hiện khuôn mặt',
      color: AppColors.textMuted,
    ),
    FaceScanState.hasSuggestions => (
      text: 'Có gợi ý',
      color: AppColors.success,
    ),
    FaceScanState.failed => (text: 'Quét thất bại', color: AppColors.danger),
    FaceScanState.notScanned => (text: 'Chưa quét', color: AppColors.textMuted),
  };

  @override
  Widget build(BuildContext context) {
    // Face suggestion chỉ cho ảnh; video không quét mặt.
    if (!widget.isImage) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.face_retouching_natural_rounded,
                size: 20,
                color: AppColors.primary500,
              ),
              const SizedBox(width: 8),
              Text(
                'Người trong ảnh',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!_face.canUseFaceSuggestions)
            _lockedNote()
          else ...[
            _scanRow(),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._suggestions.map(_suggestionTile),
            ] else if (_scan == FaceScanState.scanned ||
                _scan == FaceScanState.noFace) ...[
              const SizedBox(height: 8),
              Text(
                'Chưa có gợi ý nào. Bạn vẫn có thể gắn thẻ thủ công.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _lockedNote() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      'Nhận diện người trong ảnh là tính năng của gói nâng cao. Bạn vẫn có thể '
      'gắn thẻ thành viên thủ công.',
      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
    ),
  );

  Widget _scanRow() {
    final chip = _statusChip;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chip.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            chip.text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: chip.color,
            ),
          ),
        ),
        const Spacer(),
        if (widget.isSafe)
          TextButton.icon(
            onPressed: _busy || _scan == FaceScanState.processing
                ? null
                : _scanNow,
            icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
            label: Text(
              _scan == FaceScanState.notScanned ? 'Quét khuôn mặt' : 'Quét lại',
            ),
          ),
      ],
    );
  }

  Widget _suggestionTile(FaceSuggestion s) {
    final conf = _confidenceLabel(s.confidence);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary50,
            child: Icon(Icons.person, size: 18, color: AppColors.primary500),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _memberName(s.memberId),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (conf.isNotEmpty)
                  Text(
                    'Độ tin cậy $conf',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Xác nhận',
            onPressed: _busy ? null : () => _resolve(s, confirm: true),
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
            ),
          ),
          IconButton(
            tooltip: 'Từ chối',
            onPressed: _busy ? null : () => _resolve(s, confirm: false),
            icon: const Icon(Icons.cancel_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
