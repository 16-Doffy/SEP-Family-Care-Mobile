import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/album_face_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

/// Câu giải thích khi danh sách gợi ý rỗng.
///
/// Rỗng có ba nguyên nhân khác hẳn nhau, trước đây gộp chung một câu nên báo
/// sai: xác nhận gợi ý xong (thẻ đã tạo) vẫn bị in lý do thất bại. Hàm thuần,
/// tách khỏi BuildContext để unit test được.
String emptySuggestionsMessage({
  required bool resolvedSomeSuggestion,
  required bool hasAnyTag,
}) {
  // Vừa Xác nhận / Bỏ qua xong — rỗng là kết quả mong đợi, không phải lỗi.
  if (resolvedSomeSuggestion) {
    return 'Đã xử lý xong toàn bộ gợi ý. Thẻ bạn xác nhận đã được tạo. '
        'Bấm “Quét lại” nếu muốn AI tìm thêm người khác trong ảnh.';
  }
  // Ảnh đã có thẻ → BE không gợi ý lại người đã được gắn thẻ.
  if (hasAnyTag) {
    return 'Chưa có gợi ý mới. Những người đã được gắn thẻ trong ảnh này sẽ '
        'không được gợi ý lại — gỡ thẻ rồi quét lại nếu muốn AI nhận diện '
        'từ đầu.';
  }
  return 'Chưa có gợi ý nào. Thường do khuôn mặt trong ảnh quá nhỏ, bị che '
      'hoặc chưa ai đăng ký Hồ sơ khuôn mặt. Bạn vẫn có thể gắn thẻ thủ công.';
}

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
    required this.taggedMemberIds,
    required this.hasAnyTag,
    this.onChanged,
  });

  final String mediaId;
  final bool isImage;
  final bool isSafe;

  /// Id thành viên đã được gắn thẻ trên media (memberId hoặc userId tùy BE trả).
  /// Dùng để không hiện lại gợi ý cho người vốn đã có thẻ trong ảnh.
  final Set<String> taggedMemberIds;

  /// Ảnh đã có thẻ nào chưa — **không** suy ra từ [taggedMemberIds].
  ///
  /// Đo trên máy thật 19/08: chip thẻ hiện đúng tên thành viên nhưng
  /// [taggedMemberIds] lại rỗng, tức BE trả tên mà không trả id ở bất kỳ field
  /// nào parser đang thử (`taggedMemberId` / `memberId` / `userId` /
  /// `member.id` / `user.id`). Việc chọn câu thông báo chỉ cần biết "có thẻ hay
  /// không" nên đọc thẳng số thẻ, không phụ thuộc id. Đã hỏi BE id nằm ở đâu.
  final bool hasAnyTag;

  final VoidCallback? onChanged;

  @override
  State<AlbumFaceSection> createState() => _AlbumFaceSectionState();
}

class _AlbumFaceSectionState extends State<AlbumFaceSection> {
  FaceScanState _scan = FaceScanState.notScanned;
  List<FaceSuggestion> _suggestions = const [];
  bool _loading = true;
  bool _busy = false;
  bool _scanWaitingTooLong = false;
  bool _retryAllowed = false;
  int? _maxProcessingSeconds;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  /// Người dùng đã Xác nhận / Bỏ qua ít nhất một gợi ý trong lượt xem này.
  ///
  /// Danh sách gợi ý rỗng có hai nguyên nhân trái ngược nhau: quét không ra ai,
  /// hoặc **đã xử lý hết**. Không phân biệt thì sau khi xác nhận thành công màn
  /// hình lại in lý do thất bại ("khuôn mặt quá nhỏ, bị che…") ngay bên cạnh
  /// cái thẻ vừa tạo xong. Đặt lại mỗi lần quét lại vì lúc đó là lượt mới.
  bool _resolvedSomeSuggestion = false;

  AlbumFaceProvider get _face => context.read<AlbumFaceProvider>();
  SubscriptionProvider get _sub => context.read<SubscriptionProvider>();

  Future<void> _ensureMembersLoaded() async {
    final family = context.read<FamilyProvider>();
    if (family.members.isNotEmpty) return;
    try {
      await family.fetchMembers();
    } catch (_) {
      // Tên gợi ý vẫn có thể lấy trực tiếp từ response face-suggestions.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.isImage) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _ensureMembersLoaded();
    if (!_sub.canUseFaceSuggestions) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      var info = await _face.fetchScanInfo(widget.mediaId);
      var scan = info.state;
      var sug = await _face.fetchSuggestions(widget.mediaId);

      if (_shouldAutoScan(scan, sug)) {
        try {
          await _face.requestScan(widget.mediaId);
          final result = await _pollScanStatus(waitBeforeFirstCheck: true);
          info = result.info;
          scan = info.state;
          sug = result.suggestions;
        } catch (error) {
          _handleScanError(error, showOtherErrors: false);
          // Keep the manual scan button available if the priority scan fails.
        }
      } else if (scan == FaceScanState.processing && sug.isEmpty) {
        final result = await _pollScanStatus();
        info = result.info;
        scan = info.state;
        sug = result.suggestions;
      }

      if (!mounted) return;
      setState(() {
        _scan = sug.isNotEmpty ? FaceScanState.hasSuggestions : scan;
        _suggestions = sug;
        _scanWaitingTooLong = scan == FaceScanState.processing && sug.isEmpty;
        _retryAllowed = info.retryAllowed;
        _maxProcessingSeconds = info.maxProcessingSeconds;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _shouldAutoScan(FaceScanState scan, List<FaceSuggestion> suggestions) {
    return widget.isSafe &&
        widget.taggedMemberIds.isEmpty &&
        suggestions.isEmpty &&
        scan == FaceScanState.notScanned;
  }

  /// Số nhịp liên tiếp thấy `scanned` mà gợi ý vẫn rỗng — xem giải thích trong
  /// vòng lặp bên dưới. Đặt lại mỗi lần bắt đầu một lượt poll mới.
  int _emptyScannedStreak = 0;

  Future<({FaceScanStatusInfo info, List<FaceSuggestion> suggestions})>
  _pollScanStatus({bool waitBeforeFirstCheck = false}) async {
    _emptyScannedStreak = 0;
    var info = const FaceScanStatusInfo(state: FaceScanState.processing);
    var suggestions = const <FaceSuggestion>[];

    for (var attempt = 0; attempt < 8; attempt++) {
      if (waitBeforeFirstCheck || attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      if (!mounted) return (info: info, suggestions: suggestions);

      try {
        info = await _face.fetchScanInfo(widget.mediaId);
        suggestions = await _face.fetchSuggestions(widget.mediaId);
      } catch (_) {
        if (attempt == 7) rethrow;
        continue;
      }

      if (suggestions.isNotEmpty) {
        return (
          info: FaceScanStatusInfo(
            state: FaceScanState.hasSuggestions,
            retryAllowed: info.retryAllowed,
            maxProcessingSeconds: info.maxProcessingSeconds,
          ),
          suggestions: suggestions,
        );
      }
      final scan = info.state;
      // `noFace`/`failed` là kết luận cuối, dừng ngay được.
      if (scan == FaceScanState.noFace || scan == FaceScanState.failed) {
        return (info: info, suggestions: suggestions);
      }
      // `scanned` KHÔNG được coi là kết luận cuối khi gợi ý còn rỗng.
      //
      // BE đánh dấu job xong và ghi bảng gợi ý là hai bước riêng. Lệch nhau
      // vài trăm mili-giây là đủ để FE thấy "scanned + 0 gợi ý", thoát vòng
      // lặp, rồi KHÔNG BAO GIỜ đọc lại — người dùng thấy "Đã quét · Chưa có
      // gợi ý nào" dù BE có kết quả ngay sau đó. Bỏ lỡ vĩnh viễn vì không có
      // cơ chế tự đọc lại.
      //
      // Đọc thêm 2 nhịp (~3 giây) rồi mới kết luận là rỗng thật.
      if (scan == FaceScanState.scanned) {
        if (suggestions.isNotEmpty) {
          return (info: info, suggestions: suggestions);
        }
        _emptyScannedStreak++;
        if (_emptyScannedStreak >= 3) {
          return (info: info, suggestions: suggestions);
        }
      }
    }

    return (info: info, suggestions: suggestions);
  }

  Future<void> _scanNow() async {
    setState(() {
      _busy = true;
      _scanWaitingTooLong = false;
      // Lượt quét mới → kết quả cũ không còn nói lên điều gì.
      _resolvedSomeSuggestion = false;
    });
    try {
      final isAlreadyProcessing = _scan == FaceScanState.processing;
      if (_retryAllowed) {
        await _face.retryScan(widget.mediaId);
      } else if (!isAlreadyProcessing) {
        await _face.requestScan(
          widget.mediaId,
          force: _scan != FaceScanState.notScanned,
        );
      }
      // Quét chạy nền (202). Đợi một nhịp rồi lấy trạng thái + gợi ý.
      final result = await _pollScanStatus(
        waitBeforeFirstCheck: !isAlreadyProcessing,
      );
      if (!mounted) return;
      setState(() {
        _scan = result.suggestions.isNotEmpty
            ? FaceScanState.hasSuggestions
            : result.info.state;
        _suggestions = result.suggestions;
        _scanWaitingTooLong =
            result.info.state == FaceScanState.processing &&
            result.suggestions.isEmpty;
        _retryAllowed = result.info.retryAllowed;
        _maxProcessingSeconds = result.info.maxProcessingSeconds;
      });
    } catch (e) {
      _handleScanError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleScanError(Object error, {bool showOtherErrors = true}) {
    if (error is ApiException &&
        error.code == 'FACE_SCAN_FORCE_RESCAN_RATE_LIMITED') {
      _startCooldown(error.retryAfterSeconds ?? error.cooldownSeconds ?? 60);
      return;
    }
    if (showOtherErrors) {
      _snack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownRemaining = seconds.clamp(1, 86400));
    _snack(
      'Bạn đã yêu cầu quét lại quá nhiều lần. Vui lòng thử lại sau '
      '$_cooldownRemaining giây.',
    );
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownRemaining <= 1) {
        timer.cancel();
        setState(() => _cooldownRemaining = 0);
      } else {
        setState(() => _cooldownRemaining--);
      }
    });
  }

  Future<void> _resolve(FaceSuggestion s, {required bool confirm}) async {
    setState(() => _busy = true);
    try {
      if (confirm) {
        await _face.confirmSuggestion(widget.mediaId, s.id);
      } else {
        await _face.rejectSuggestion(widget.mediaId, s.id);
      }
      if (!mounted) return;
      // Bỏ gợi ý vừa xử lý khỏi danh sách chờ TRƯỚC khi báo cho màn ngoài
      // refresh: onChanged gọi setState ở parent, làm widget này có thể bị
      // dựng lại và mất state — khi đó `!mounted` sẽ chặn luôn việc xóa gợi ý,
      // để lại gợi ý đã xác nhận kèm nút Xác nhận như chưa xử lý.
      setState(() {
        _suggestions = _suggestions.where((e) => e.id != s.id).toList();
        _resolvedSomeSuggestion = true;
      });
      _snack(confirm ? 'Đã xác nhận và gắn thẻ' : 'Đã bỏ qua gợi ý', ok: true);
      if (confirm) widget.onChanged?.call();
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

  String _memberName(FaceSuggestion suggestion) {
    if (suggestion.memberName.isNotEmpty) return suggestion.memberName;
    final id = suggestion.memberId;
    final members = context.read<FamilyProvider>().members;
    for (final m in members) {
      if (m.id == id || m.userId == id) {
        return m.name.isEmpty ? 'Thành viên' : m.name;
      }
    }
    return 'Thành viên';
  }

  /// Tag và gợi ý có thể dùng memberId hoặc userId tùy field BE trả về → mở rộng
  /// một id sang cả hai dạng qua danh sách thành viên để so khớp không bị lệch.
  Set<String> _idAliases(String id) {
    if (id.isEmpty) return const {};
    for (final m in context.read<FamilyProvider>().members) {
      if (m.id == id || m.userId == id) {
        return {m.id, m.userId}..removeWhere((e) => e.isEmpty);
      }
    }
    return {id};
  }

  /// Người đã có thẻ trong ảnh thì không cần gợi ý gắn thẻ lại nữa — phòng cả
  /// trường hợp BE giữ nguyên status gợi ý sau khi xác nhận.
  bool _alreadyTagged(FaceSuggestion s) {
    if (widget.taggedMemberIds.isEmpty) return false;
    return _idAliases(s.memberId).any(widget.taggedMemberIds.contains);
  }

  List<FaceSuggestion> get _visibleSuggestions =>
      _suggestions.where((s) => !_alreadyTagged(s)).toList();

  String _confidenceLabel(FaceSuggestion s) {
    final c = s.normalizedConfidence;
    if (c == null) return '';
    return '${(c * 100).round()}%';
  }

  /// Khi mọi gợi ý đều đã bị lọc (đã gắn thẻ xong) thì trạng thái thật là "đã
  /// quét", không còn "có gợi ý" — tránh chip báo có gợi ý mà bên dưới trống.
  FaceScanState get _effectiveScan =>
      _scan == FaceScanState.hasSuggestions && _visibleSuggestions.isEmpty
      ? FaceScanState.scanned
      : _scan;

  ({String text, Color color}) get _statusChip => switch (_effectiveScan) {
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
        color: context.colors.inputFill,
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
                  color: context.colors.textPrimary,
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
          else if (!_sub.canUseFaceSuggestions)
            _lockedNote()
          else if (!widget.isSafe)
            _waitingForModerationNote()
          else ...[
            _scanRow(),
            if (_scanWaitingTooLong && !_busy) ...[
              const SizedBox(height: 6),
              Text(
                'Máy chủ vẫn đang xử lý ảnh. Bạn có thể rời màn hình và quay lại, '
                'hoặc bấm “Kiểm tra trạng thái” mà không tạo thêm lượt quét.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.35,
                  color: context.colors.textMuted,
                ),
              ),
            ],
            if (_retryAllowed && !_busy) ...[
              const SizedBox(height: 6),
              Text(
                'Tác vụ quét đã lỗi hoặc xử lý quá lâu'
                '${_maxProcessingSeconds == null ? '' : ' (giới hạn ${_maxProcessingSeconds}s)'}. '
                'Bấm “Thử lại tác vụ quét” để tiếp tục mà không tạo yêu cầu trùng.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.danger,
                ),
              ),
            ],
            if (_visibleSuggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'AI đã so sánh từng khuôn mặt và giữ ứng viên có điểm cao '
                'nhất. Hãy xác nhận trước khi tạo thẻ chính thức.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.35,
                  color: context.colors.textMuted,
                ),
              ),
              ..._visibleSuggestions.map(_suggestionTile),
            ] else if (_effectiveScan == FaceScanState.scanned ||
                _effectiveScan == FaceScanState.noFace) ...[
              const SizedBox(height: 8),
              Text(
                emptySuggestionsMessage(
                  resolvedSomeSuggestion: _resolvedSomeSuggestion,
                  hasAnyTag: widget.hasAnyTag,
                ),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.colors.textMuted,
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

  Widget _waitingForModerationNote() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.amberLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.amberText.withValues(alpha: 0.28)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 20,
          color: AppColors.amberText,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ảnh đang chờ duyệt an toàn',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amberDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'AI chưa thể quét khuôn mặt khi ảnh còn dấu !. '
                'Người có quyền kiểm duyệt cần chọn “Duyệt thủ công” và đánh dấu ảnh an toàn trước.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.amberDark,
                ),
              ),
            ],
          ),
        ),
      ],
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
            onPressed: _busy || _cooldownRemaining > 0 ? null : _scanNow,
            icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
            label: Text(
              _cooldownRemaining > 0
                  ? 'Thử lại sau ${_cooldownRemaining}s'
                  : _retryAllowed
                  ? 'Thử lại tác vụ quét'
                  : _scan == FaceScanState.processing
                  ? 'Kiểm tra trạng thái'
                  : _scan == FaceScanState.notScanned
                  ? 'Quét khuôn mặt'
                  : 'Quét lại',
            ),
          ),
      ],
    );
  }

  Widget _suggestionTile(FaceSuggestion s) {
    final conf = _confidenceLabel(s);
    final faceLabel = s.faceIndex == null
        ? ''
        : 'Khuôn mặt ${s.faceIndex! + 1}';
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
                  _memberName(s),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (conf.isNotEmpty)
                  Text(
                    faceLabel.isEmpty
                        ? 'Độ tin cậy $conf'
                        : '$faceLabel · Độ tin cậy $conf',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: context.colors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Xác nhận',
            // BE trả `permissions.canConfirm/canReject`. Không có quyền mà vẫn
            // cho bấm thì chỉ nhận 403.
            onPressed: _busy || !s.canConfirm
                ? null
                : () => _resolve(s, confirm: true),
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
            ),
          ),
          IconButton(
            tooltip: 'Từ chối',
            onPressed: _busy || !s.canReject
                ? null
                : () => _resolve(s, confirm: false),
            icon: const Icon(Icons.cancel_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
