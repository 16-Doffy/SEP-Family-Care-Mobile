import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../wear_widgets.dart';

class WearConnectScreen extends StatelessWidget {
  const WearConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final family = user?.familyName.trim();

    return WearPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WearHeader(
            icon: Icons.watch_rounded,
            label: 'Đồng hồ',
            color: WearPalette.green,
          ),
          const SizedBox(height: 9),
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: WearPalette.surface2,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.phone_iphone_rounded,
                size: 28,
                color: WearPalette.green,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              user == null ? 'Cần ghép nối' : 'Đã kết nối',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: WearPalette.text,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              family == null || family.isEmpty ? 'FamilyCare mobile' : family,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: WearPalette.faint),
            ),
          ),
          const SizedBox(height: 10),
          const WearTile(
            icon: Icons.sync_rounded,
            title: 'Đồng bộ qua mobile',
            subtitle: 'Cài đặt và trả lời trên điện thoại',
            color: WearPalette.blue,
          ),
        ],
      ),
    );
  }
}
