import '../services/api_client.dart';

enum AlbumMediaType { photo, video, unknown }

enum AlbumVisibilityScope { family, private, managerOnly }

enum AlbumModerationStatus { pending, safe, needReview, flagged }


String _str(dynamic value) => value?.toString() ?? '';

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

double? _numOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

AlbumMediaType albumMediaTypeFromApi(dynamic value) {
  return switch (_str(value).toUpperCase()) {
    'PHOTO' || 'IMAGE' => AlbumMediaType.photo,
    'VIDEO' => AlbumMediaType.video,
    _ => AlbumMediaType.unknown,
  };
}

AlbumVisibilityScope albumVisibilityFromApi(dynamic value) {
  return switch (_str(value).toUpperCase()) {
    'PRIVATE' => AlbumVisibilityScope.private,
    'MANAGER_ONLY' => AlbumVisibilityScope.managerOnly,
    _ => AlbumVisibilityScope.family,
  };
}

AlbumModerationStatus albumModerationFromApi(dynamic value) {
  return switch (_str(value).toUpperCase()) {
    'PROCESSING' => AlbumModerationStatus.pending,
    'SAFE' => AlbumModerationStatus.safe,
    'NEED_REVIEW' => AlbumModerationStatus.needReview,
    'FLAGGED' => AlbumModerationStatus.flagged,
    _ => AlbumModerationStatus.pending,
  };
}

String albumMediaTypeToApi(AlbumMediaType value) {
  return switch (value) {
    AlbumMediaType.photo => 'PHOTO',
    AlbumMediaType.video => 'VIDEO',
    AlbumMediaType.unknown => '',
  };
}

String albumVisibilityToApi(AlbumVisibilityScope value) {
  return switch (value) {
    AlbumVisibilityScope.family => 'FAMILY',
    AlbumVisibilityScope.private => 'PRIVATE',
    AlbumVisibilityScope.managerOnly => 'MANAGER_ONLY',
  };
}

String albumModerationToApi(AlbumModerationStatus value) {
  return switch (value) {
    AlbumModerationStatus.pending => 'PENDING',
    AlbumModerationStatus.safe => 'SAFE',
    AlbumModerationStatus.needReview => 'NEED_REVIEW',
    AlbumModerationStatus.flagged => 'FLAGGED',
  };
}

class AlbumTag {
  final String id;
  final String taggedMemberId;
  final String taggedMemberName;
  final String? tagNote;
  final bool canRemove;

  const AlbumTag({
    required this.id,
    required this.taggedMemberId,
    required this.taggedMemberName,
    this.tagNote,
    this.canRemove = false,
  });

  factory AlbumTag.fromJson(Map<String, dynamic> json) {
    final member = _map(json['taggedMember']) ?? _map(json['member']);
    final user = _map(member?['user']);
    return AlbumTag(
      id: _str(json['tagId'] ?? json['id']),
      taggedMemberId: _str(json['taggedMemberId'] ?? member?['id']),
      taggedMemberName: _str(
        member?['displayName'] ??
            user?['fullName'] ??
            json['taggedMemberName'] ??
            'Thanh vien',
      ),
      tagNote: json['tagNote']?.toString(),
      canRemove: (json['permissions'] is Map
              ? (json['permissions'] as Map)['canRemove']
              : json['canRemove']) ==
          true,
    );
  }
}

class AlbumMedia {
  final String id;
  final AlbumMediaType mediaType;
  final AlbumVisibilityScope visibilityScope;
  final AlbumModerationStatus moderationStatus;
  final String? caption;
  final String? uploaderMemberId;
  final String uploaderName;
  final String? fileUrl;
  final String? thumbnailUrl;
  final int? fileSize;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  final double? latestRiskScore;
  final String? latestModerationSummary;
  final List<AlbumTag> tags;
  final Map<String, dynamic> raw;

  const AlbumMedia({
    required this.id,
    required this.mediaType,
    required this.visibilityScope,
    required this.moderationStatus,
    this.caption,
    this.uploaderMemberId,
    required this.uploaderName,
    this.fileUrl,
    this.thumbnailUrl,
    this.fileSize,
    this.createdAt,
    this.deletedAt,
    this.latestRiskScore,
    this.latestModerationSummary,
    this.tags = const [],
    this.raw = const {},
  });

  bool get isVideo => mediaType == AlbumMediaType.video;
  bool get isPending => moderationStatus == AlbumModerationStatus.pending;
  bool get needsReview =>
      moderationStatus == AlbumModerationStatus.needReview ||
      moderationStatus == AlbumModerationStatus.flagged;
  bool get isSafe => moderationStatus == AlbumModerationStatus.safe;
  bool get canManualReview => !isSafe;

  String get displayUrl => thumbnailUrl ?? fileUrl ?? '';

  factory AlbumMedia.fromJson(Map<String, dynamic> json) {
    final fileAccess = _map(json['fileAccess']);
    final latestModeration = _map(json['latestModeration']);
    final uploader = _map(json['uploaderMember']) ?? _map(json['uploader']);
    final user = _map(uploader?['user']);
    final tags = (json['tags'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AlbumTag.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    String? urlFrom(dynamic value) {
      final url = value?.toString();
      if (url == null || url.isEmpty) return null;
      return ApiClient.absoluteUrl(url);
    }

    return AlbumMedia(
      id: _str(json['mediaId'] ?? json['id']),
      mediaType: albumMediaTypeFromApi(json['mediaType'] ?? json['fileType']),
      visibilityScope: albumVisibilityFromApi(json['visibilityScope']),
      moderationStatus: albumModerationFromApi(json['moderationStatus']),
      caption: json['caption']?.toString(),
      uploaderMemberId:
          json['uploaderMemberId']?.toString() ?? uploader?['id']?.toString(),
      uploaderName: _str(
        uploader?['displayName'] ??
            user?['fullName'] ??
            json['uploaderName'] ??
            'Thanh vien',
      ),
      fileUrl: urlFrom(
        fileAccess?['url'] ??
            json['fileUrl'] ??
            json['url'] ??
            json['signedUrl'],
      ),
      thumbnailUrl: urlFrom(
        fileAccess?['thumbnailUrl'] ??
            fileAccess?['thumbnail'] ??
            json['thumbnailUrl'] ??
            json['previewUrl'],
      ),
      fileSize:
          (json['fileSize'] as num?)?.toInt() ??
          (json['size'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(
        _str(json['createdAt'] ?? json['uploadedAt']),
      )?.toLocal(),
      deletedAt: DateTime.tryParse(_str(json['deletedAt']))?.toLocal(),
      latestRiskScore: _numOrNull(
        latestModeration?['riskScore'] ?? json['riskScore'],
      ),
      latestModerationSummary:
          latestModeration?['summary']?.toString() ??
          json['moderationSummary']?.toString(),
      tags: tags,
      raw: json,
    );
  }

  AlbumMedia merge(AlbumMedia detail) {
    return AlbumMedia(
      id: id,
      mediaType: detail.mediaType == AlbumMediaType.unknown
          ? mediaType
          : detail.mediaType,
      visibilityScope: detail.visibilityScope,
      moderationStatus: detail.moderationStatus,
      caption: detail.caption ?? caption,
      uploaderMemberId: detail.uploaderMemberId ?? uploaderMemberId,
      uploaderName: detail.uploaderName.isNotEmpty
          ? detail.uploaderName
          : uploaderName,
      fileUrl: detail.fileUrl ?? fileUrl,
      thumbnailUrl: detail.thumbnailUrl ?? thumbnailUrl,
      fileSize: detail.fileSize ?? fileSize,
      createdAt: detail.createdAt ?? createdAt,
      deletedAt: detail.deletedAt ?? deletedAt,
      latestRiskScore: detail.latestRiskScore ?? latestRiskScore,
      latestModerationSummary:
          detail.latestModerationSummary ?? latestModerationSummary,
      tags: detail.tags.isNotEmpty ? detail.tags : tags,
      raw: {...raw, ...detail.raw},
    );
  }

  AlbumMedia withTags(List<AlbumTag> nextTags) => AlbumMedia(
    id: id,
    mediaType: mediaType,
    visibilityScope: visibilityScope,
    moderationStatus: moderationStatus,
    caption: caption,
    uploaderMemberId: uploaderMemberId,
    uploaderName: uploaderName,
    fileUrl: fileUrl,
    thumbnailUrl: thumbnailUrl,
    fileSize: fileSize,
    createdAt: createdAt,
    deletedAt: deletedAt,
    latestRiskScore: latestRiskScore,
    latestModerationSummary: latestModerationSummary,
    tags: nextTags,
    raw: raw,
  );
}
