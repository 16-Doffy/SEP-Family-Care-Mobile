typedef SosAlertLocation = ({double lat, double lng, String? sourceType});
typedef SosAlertLocationPoint = ({
  double lat,
  double lng,
  String? sourceType,
  DateTime? recordedAt,
});

SosAlertLocation? parseSosAlertLocation(Map<String, dynamic> data) {
  final points = parseSosAlertLocationPoints(data);
  if (points.isNotEmpty) {
    final latest = points.last;
    return (lat: latest.lat, lng: latest.lng, sourceType: latest.sourceType);
  }

  final lat = _doubleOf(data['latitude'] ?? data['initialLatitude']);
  final lng = _doubleOf(data['longitude'] ?? data['initialLongitude']);
  if (lat != null && lng != null) {
    return (lat: lat, lng: lng, sourceType: data['sourceType']?.toString());
  }
  return null;
}

List<SosAlertLocationPoint> parseSosAlertLocationPoints(
  Map<String, dynamic> data,
) {
  for (final key in const ['locationPoints', 'locations', 'sosLocations']) {
    final points = _validLocationPoints(data[key]);
    if (points.isNotEmpty) {
      points.sort((a, b) {
        final at = a.recordedAt;
        final bt = b.recordedAt;
        if (at == null && bt == null) return a.index.compareTo(b.index);
        if (at == null) return -1;
        if (bt == null) return 1;
        final byTime = at.compareTo(bt);
        return byTime == 0 ? a.index.compareTo(b.index) : byTime;
      });
      return [
        for (final p in points)
          (
            lat: p.lat,
            lng: p.lng,
            sourceType: p.sourceType,
            recordedAt: p.recordedAt,
          ),
      ];
    }
  }

  return const [];
}

List<_SosLocationPoint> _validLocationPoints(dynamic value) {
  if (value is! List) return const [];
  final points = <_SosLocationPoint>[];
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item is! Map) continue;
    final lat = _doubleOf(item['latitude']);
    final lng = _doubleOf(item['longitude']);
    if (lat == null || lng == null) continue;
    points.add(
      _SosLocationPoint(
        index: i,
        lat: lat,
        lng: lng,
        sourceType: item['sourceType']?.toString(),
        recordedAt: _dateOf(item['recordedAt'] ?? item['createdAt']),
      ),
    );
  }
  return points;
}

double? _doubleOf(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _dateOf(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

class _SosLocationPoint {
  const _SosLocationPoint({
    required this.index,
    required this.lat,
    required this.lng,
    required this.sourceType,
    required this.recordedAt,
  });

  final int index;
  final double lat;
  final double lng;
  final String? sourceType;
  final DateTime? recordedAt;
}
