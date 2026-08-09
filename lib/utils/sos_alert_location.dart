({double lat, double lng})? parseSosAlertLocation(Map<String, dynamic> data) {
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
      final latest = points.last;
      return (lat: latest.lat, lng: latest.lng);
    }
  }

  final lat = _doubleOf(data['latitude'] ?? data['initialLatitude']);
  final lng = _doubleOf(data['longitude'] ?? data['initialLongitude']);
  if (lat != null && lng != null) return (lat: lat, lng: lng);
  return null;
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
    required this.recordedAt,
  });

  final int index;
  final double lat;
  final double lng;
  final DateTime? recordedAt;
}
