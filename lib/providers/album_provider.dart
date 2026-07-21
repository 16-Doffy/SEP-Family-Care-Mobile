import 'package:flutter/foundation.dart';

import '../models/album_media.dart';
import '../services/api_client.dart';

class AlbumProvider extends ChangeNotifier {
  final List<AlbumMedia> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _uploading = false;
  String? _error;
  int _page = 1;
  int _limit = 20;
  int? _totalPages;
  AlbumMediaType? _mediaType;
  AlbumModerationStatus? _moderationStatus;

  List<AlbumMedia> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get uploading => _uploading;
  String? get error => _error;
  int get page => _page;
  int get limit => _limit;
  AlbumMediaType? get mediaType => _mediaType;
  AlbumModerationStatus? get moderationStatus => _moderationStatus;
  bool get hasMore =>
      _totalPages == null ? _items.length >= _limit : _page < _totalPages!;
  bool get hasPendingItems => _items.any((m) => m.isPending);

  String get _fid {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chua co gia dinh');
    return fid;
  }

  Future<void> fetchMedia({
    bool refresh = true,
    AlbumMediaType? mediaType,
    AlbumModerationStatus? moderationStatus,
    int? limit,
  }) async {
    if (refresh) {
      _loading = true;
      _page = 1;
      _totalPages = null;
      _mediaType = mediaType;
      _moderationStatus = moderationStatus;
      if (limit != null) _limit = limit;
    } else {
      if (_loadingMore || !hasMore) return;
      _loadingMore = true;
    }
    _error = null;
    notifyListeners();

    try {
      final nextPage = refresh ? 1 : _page + 1;
      final data = await ApiClient.instance.get(
        '/families/$_fid/albums/media${_qs({'page': nextPage, 'limit': _limit, 'mediaType': _mediaType == null ? null : albumMediaTypeToApi(_mediaType!), 'moderationStatus': _moderationStatus == null ? null : albumModerationToApi(_moderationStatus!)})}',
      );
      final parsed = _list(
        data,
      ).map(AlbumMedia.fromJson).where((m) => m.id.isNotEmpty).toList();
      if (refresh) {
        _items
          ..clear()
          ..addAll(parsed);
      } else {
        _items.addAll(parsed);
      }
      _page = nextPage;
      _totalPages = _readTotalPages(data, parsed.length);
    } catch (e) {
      _error = e.toString();
      if (refresh) _items.clear();
    } finally {
      _loading = false;
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Ảnh có gắn thẻ một thành viên — cho tab "Theo thành viên" (kiểu Google
  /// Photos → Mọi người). Dùng filter taggedMemberId của BE. Trả list riêng,
  /// KHÔNG đụng _items của lưới chính.
  Future<List<AlbumMedia>> fetchTaggedMedia(String memberId) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/albums/media${_qs({'taggedMemberId': memberId, 'limit': 100, 'sortOrder': 'DESC'})}',
    );
    return _list(
      data,
    ).map(AlbumMedia.fromJson).where((m) => m.id.isNotEmpty).toList();
  }

  Future<AlbumMedia?> fetchDetail(String mediaId) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/albums/media/$mediaId',
    );
    if (data is! Map) return null;
    var detail = AlbumMedia.fromJson(Map<String, dynamic>.from(data));
    // Tags are a separate manual-tagging resource in the current contract.
    try {
      detail = detail.withTags(await fetchTags(mediaId));
    } catch (_) {
      // Keep detail usable if a signed URL/detail succeeds but tags cannot load.
    }
    final idx = _items.indexWhere((m) => m.id == mediaId);
    if (idx >= 0) _items[idx] = _items[idx].merge(detail, replaceTags: true);
    notifyListeners();
    return detail;
  }

  // URL đã nạp cho ô lưới → giữ để lần rebuild sau (cuộn qua rồi cuộn lại)
  // không gọi lại API. Tách khỏi _items vì nhiều ô có thể đang chờ cùng lúc.
  final Map<String, String> _resolvedUrls = {};
  final Map<String, Future<String?>> _resolving = {};

  /// Lấy URL hiển thị cho một ô lưới. API list KHÔNG trả signed URL (chỉ detail
  /// mới có — xác minh 2026-07-21), nên ô thiếu URL phải gọi detail để lấy.
  /// Chỉ GET media, KHÔNG kèm tags như fetchDetail cho nhẹ. De-dup lời gọi
  /// trùng và cache kết quả.
  Future<String?> resolveDisplayUrl(AlbumMedia media) {
    if (media.displayUrl.isNotEmpty) return Future.value(media.displayUrl);
    final cached = _resolvedUrls[media.id];
    if (cached != null) return Future.value(cached);

    return _resolving.putIfAbsent(media.id, () async {
      try {
        final data = await ApiClient.instance.get(
          '/families/$_fid/albums/media/${media.id}',
        );
        if (data is! Map) return null;
        final detail = AlbumMedia.fromJson(Map<String, dynamic>.from(data));
        final url = detail.displayUrl;
        if (url.isEmpty) return null;
        _resolvedUrls[media.id] = url;
        // Nhét URL vào _items để ô giữ ảnh qua các lần rebuild; không notify để
        // tránh bão rebuild — FutureBuilder ở ô tự cập nhật khi future xong.
        final idx = _items.indexWhere((m) => m.id == media.id);
        if (idx >= 0) _items[idx] = _items[idx].merge(detail);
        return url;
      } catch (_) {
        return null; // ô sẽ hiện icon lỗi, không làm sập lưới
      } finally {
        _resolving.remove(media.id);
      }
    });
  }

  Future<void> uploadMedia({
    required String filePath,
    String? caption,
    AlbumVisibilityScope visibilityScope = AlbumVisibilityScope.family,
  }) async {
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.uploadFile(
        path: '/families/$_fid/albums/media',
        filePath: filePath,
        fields: {
          if (caption != null && caption.trim().isNotEmpty)
            'caption': caption.trim(),
          'visibilityScope': albumVisibilityToApi(visibilityScope),
        },
      );
      await fetchMedia(refresh: true);
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<void> updateMedia(
    String mediaId, {
    String? caption,
    AlbumVisibilityScope? visibilityScope,
  }) async {
    await ApiClient.instance.patch('/families/$_fid/albums/media/$mediaId', {
      'caption': ?caption,
      'visibilityScope': ?(visibilityScope == null
          ? null
          : albumVisibilityToApi(visibilityScope)),
    });
    await fetchDetail(mediaId);
  }

  Future<void> softDelete(
    String mediaId, {
    String reason = 'Deleted from mobile app',
  }) async {
    await ApiClient.instance.delete(
      '/families/$_fid/albums/media/$mediaId',
      body: {'reason': reason},
    );
    _items.removeWhere((m) => m.id == mediaId);
    notifyListeners();
  }

  Future<void> restore(String mediaId) async {
    await ApiClient.instance.post(
      '/families/$_fid/albums/media/$mediaId/restore',
      {},
    );
    _items.removeWhere((m) => m.id == mediaId);
    notifyListeners();
  }

  Future<void> permanentDelete(String mediaId) async {
    await ApiClient.instance.delete(
      '/families/$_fid/albums/media/$mediaId/permanent',
      body: {'confirmation': 'PERMANENT_DELETE'},
    );
    _items.removeWhere((m) => m.id == mediaId);
    notifyListeners();
  }

  Future<List<AlbumTag>> fetchTags(String mediaId) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/albums/media/$mediaId/tags',
    );
    return _list(data).map(AlbumTag.fromJson).toList();
  }

  Future<void> tagMember(
    String mediaId,
    String taggedMemberId, {
    String? tagNote,
  }) async {
    await ApiClient.instance
        .post('/families/$_fid/albums/media/$mediaId/tags', {
          'taggedMemberId': taggedMemberId,
          if (tagNote != null && tagNote.trim().isNotEmpty)
            'tagNote': tagNote.trim(),
        });
    await fetchDetail(mediaId);
  }

  Future<void> untagMember(String mediaId, String tagId) async {
    await ApiClient.instance.delete(
      '/families/$_fid/albums/media/$mediaId/tags/$tagId',
    );
    await fetchDetail(mediaId);
  }

  // GET .../albums/moderation — hàng đợi kiểm duyệt thủ công của Manager.
  Future<List<Map<String, dynamic>>> fetchModerationQueue() async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/albums/moderation',
    );
    return _list(data);
  }

  Future<Map<String, dynamic>> fetchModeration(String mediaId) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/albums/media/$mediaId/moderation',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> reviewModeration(
    String mediaId, {
    required String decision,
    required String reviewNote,
  }) async {
    await ApiClient.instance.patch(
      '/families/$_fid/albums/media/$mediaId/moderation',
      {'decision': decision, 'reviewNote': reviewNote},
    );
    await fetchDetail(mediaId);
  }

  String _qs(Map<String, dynamic> params) {
    final entries = params.entries.where(
      (e) => e.value != null && e.value.toString().isNotEmpty,
    );
    if (entries.isEmpty) return '';
    return '?${entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value.toString())}').join('&')}';
  }

  static List<Map<String, dynamic>> _list(dynamic data) {
    final raw = data is List
        ? data
        : data is Map && data['items'] is List
        ? data['items'] as List
        : data is Map && data['data'] is List
        ? data['data'] as List
        : data is Map && data['media'] is List
        ? data['media'] as List
        : <dynamic>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int? _readTotalPages(dynamic data, int fetchedCount) {
    if (data is! Map) return fetchedCount < _limit ? _page : null;
    final meta = data['meta'] is Map
        ? data['meta'] as Map
        : data['pagination'] is Map
        ? data['pagination'] as Map
        : data;
    final totalPages = (meta['totalPages'] as num?)?.toInt();
    if (totalPages != null) return totalPages;
    final total = (meta['total'] as num?)?.toInt();
    if (total != null) return (total / _limit).ceil().clamp(1, 1 << 30);
    final hasNext = meta['hasNext'] == true || meta['hasNextPage'] == true;
    return hasNext ? null : _page;
  }
}
