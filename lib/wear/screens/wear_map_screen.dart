import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/gps_provider.dart';
import '../wear_utils.dart';

/// Vị trí gia đình trên đồng hồ.
///
/// **Cố ý KHÔNG nhúng bản đồ tile** như app điện thoại: màn hình tròn ~1.2 inch
/// không đọc được bản đồ, lại tốn pin và mạng. Ở đây chỉ liệt kê ai đang chia sẻ
/// vị trí và cập nhật lúc nào — muốn xem bản đồ thật thì mở điện thoại.
class WearMapScreen extends StatefulWidget {
  const WearMapScreen({super.key});

  @override
  State<WearMapScreen> createState() => _WearMapScreenState();
}

class _WearMapScreenState extends State<WearMapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<GpsProvider>().fetchFamilyLocations(),
    );
  }

  /// "5 phút trước" — trên đồng hồ, độ mới của vị trí quan trọng hơn toạ độ.
  String _ago(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'vua xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phut';
    if (d.inHours < 24) return '${d.inHours} gio';
    return '${d.inDays} ngay';
  }

  @override
  Widget build(BuildContext context) {
    final padding = WearUtils.safePadding(context);
    final sharing = context
        .watch<GpsProvider>()
        .shares
        .where((s) => s.isSharing && s.latitude != null)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding.left, 10, padding.right, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Vi tri gia dinh',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: sharing.isEmpty
                    ? const Center(
                        child: Text(
                          'Chua ai chia se vi tri',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, color: Colors.white38),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: sharing.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 5),
                        itemBuilder: (_, i) {
                          final s = sharing[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF171717),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_pin_circle_rounded,
                                  size: 13,
                                  color: Color(0xFF22C55E),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    s.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Text(
                                  _ago(s.updatedAt),
                                  style: const TextStyle(
                                    fontSize: 7.5,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
