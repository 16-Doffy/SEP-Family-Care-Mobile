import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/gps_provider.dart';
import '../wear_widgets.dart';

class WearMapScreen extends StatefulWidget {
  const WearMapScreen({super.key});

  @override
  State<WearMapScreen> createState() => _WearMapScreenState();
}

class _WearMapScreenState extends State<WearMapScreen> {
  final _mapController = MapController();
  double _zoom = 15;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<GpsProvider>().fetchFamilyLocations(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GpsProvider>();
    final sharing = gps.shares
        .where((s) => s.isSharing && s.latitude != null && s.longitude != null)
        .toList();
    if (_selected >= sharing.length) _selected = 0;

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearHeader(
            icon: Icons.location_on_rounded,
            label: 'Định vị',
            color: WearPalette.blue,
            trailing: gps.loading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WearPalette.blue,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          if (gps.sharingUnavailable)
            const WearEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Map chưa sẵn sàng',
              subtitle: 'Mở mobile để xem bản đồ',
            )
          else if (sharing.isEmpty)
            const WearEmptyState(
              icon: Icons.location_off_rounded,
              title: 'Chưa có vị trí',
              subtitle: 'Đồng bộ từ mobile',
            )
          else ...[
            _mapCard(sharing),
            const SizedBox(height: 8),
            _zoomRow(sharing[_selected]),
            const SizedBox(height: 10),
            const WearSectionLabel('Thành viên'),
            ...sharing.map((share) {
              final i = sharing.indexOf(share);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: WearTile(
                  icon: Icons.person_pin_circle_rounded,
                  title: share.displayName,
                  subtitle: _ago(share.updatedAt),
                  color: i == _selected ? WearPalette.green : WearPalette.blue,
                  filled: i == _selected,
                  trailing: const Icon(
                    Icons.near_me_rounded,
                    size: 18,
                    color: WearPalette.faint,
                  ),
                  onTap: () {
                    setState(() => _selected = i);
                    _moveTo(share);
                  },
                ),
              );
            }),
            WearPillButton(
              label: 'Chỉ đường',
              icon: Icons.directions_rounded,
              color: WearPalette.blue,
              onTap: () => _openDirections(sharing[_selected]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mapCard(List<LocationShare> sharing) {
    final selected = sharing[_selected];
    final center = LatLng(selected.latitude!, selected.longitude!);
    final large = wearIsLarge(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: large ? 142 : 118,
        width: double.infinity,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: _zoom,
            minZoom: 3,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags:
                  InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.company.familycare',
            ),
            MarkerLayer(
              markers: sharing.map((share) {
                final active = share == selected;
                return Marker(
                  point: LatLng(share.latitude!, share.longitude!),
                  width: active ? 38 : 30,
                  height: active ? 38 : 30,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selected = sharing.indexOf(share));
                      _moveTo(share);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? WearPalette.blue : WearPalette.green,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomRow(LocationShare selected) {
    return Row(
      children: [
        Expanded(
          child: WearPillButton(
            label: '-',
            icon: Icons.remove_rounded,
            color: WearPalette.surface2,
            onTap: () => _zoomBy(selected, -1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: WearPillButton(
            label: '+',
            icon: Icons.add_rounded,
            color: WearPalette.surface2,
            onTap: () => _zoomBy(selected, 1),
          ),
        ),
      ],
    );
  }

  void _zoomBy(LocationShare share, double delta) {
    setState(() => _zoom = (_zoom + delta).clamp(3, 18).toDouble());
    _moveTo(share);
  }

  void _moveTo(LocationShare share) {
    _mapController.move(LatLng(share.latitude!, share.longitude!), _zoom);
  }

  Future<void> _openDirections(LocationShare share) async {
    final lat = share.latitude;
    final lng = share.longitude;
    if (lat == null || lng == null) return;
    final query = Uri.encodeComponent('$lat,$lng(${share.displayName})');
    final uri = Uri.parse('geo:$lat,$lng?q=$query');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      final web = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  String _ago(String? iso) {
    if (iso == null || iso.isEmpty) return 'đang cập nhật';
    final time = DateTime.tryParse(iso);
    if (time == null) return 'đang cập nhật';
    final delta = DateTime.now().difference(time.toLocal());
    if (delta.inMinutes < 1) return 'vừa xong';
    if (delta.inMinutes < 60) return '${delta.inMinutes} phút trước';
    if (delta.inHours < 24) return '${delta.inHours} giờ trước';
    return '${delta.inDays} ngày trước';
  }
}
