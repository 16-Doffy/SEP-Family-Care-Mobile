import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../wear_widgets.dart';
import 'wear_login_screen.dart';

class WearPairingScreen extends StatefulWidget {
  const WearPairingScreen({super.key});

  @override
  State<WearPairingScreen> createState() => _WearPairingScreenState();
}

class _WearPairingScreenState extends State<WearPairingScreen> {
  // Trước đây màn này tự sinh mã `FCW-XXXXXX` lưu vào secure storage riêng và
  // hiện to giữa màn hình. Đã bỏ vì hai lý do:
  //  1. Mã đó KHÔNG BAO GIỜ được gửi lên server — không endpoint nào nhận nó,
  //     nên người dùng đi tìm chỗ nhập không tồn tại.
  //  2. Định danh thiết bị nay do `WearableProvider.deviceIdentifier()` quản lý
  //     (mã cố định theo từng bản cài, dùng cho `PairWearableDto`), tránh hai
  //     cơ chế song song cho cùng một khái niệm.
  bool _checking = false;

  Future<void> _checkLink() async {
    HapticFeedback.lightImpact();
    setState(() => _checking = true);
    try {
      await context.read<AuthProvider>().tryRestoreSession();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WearPage(
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.watch_rounded, size: 30, color: WearPalette.green),
          const SizedBox(height: 7),
          const Text(
            'Kết nối mobile',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: WearPalette.text,
            ),
          ),
          const SizedBox(height: 5),
          // Luồng CHÍNH THỨC (nhóm đã chốt): liên kết đồng hồ ↔ điện thoại bằng
          // token, đồng hồ KHÔNG đăng nhập bằng email/mật khẩu. Nút đăng nhập
          // bên dưới chỉ là đường phụ và sẽ bị xóa khi BE cấp 3 endpoint
          // pair-code → claim-code → exchange (DE_XUAT_BE_WEARABLE_TOKEN_2026-08-04.md).
          const Text(
            'Đồng hồ sẽ tự nhận quyền từ điện thoại đã đăng nhập',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8.5, color: WearPalette.faint),
          ),
          const SizedBox(height: 10),
          // Không hiện mã thiết bị: mã cũ sinh cục bộ và chưa từng được gửi lên
          // server, hiện ra chỉ khiến người dùng đi tìm chỗ nhập không tồn tại.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: WearPalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: WearPalette.line),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  size: 14,
                  color: WearPalette.amber,
                ),
                SizedBox(height: 3),
                Text(
                  'Liên kết từ điện thoại: máy chủ chưa hỗ trợ',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8, color: WearPalette.faint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          WearPillButton(
            label: 'Kiểm tra liên kết',
            icon: Icons.sync_rounded,
            color: WearPalette.green,
            loading: _checking,
            onTap: _checkLink,
          ),
          const SizedBox(height: 7),
          // ĐƯỜNG PHỤ, cố ý để mờ và ở dưới: nhóm đã chốt token là luồng chính,
          // gõ email/mật khẩu trên đồng hồ chỉ là tạm. Xóa nút này ngay khi BE
          // có luồng đổi mã lấy token.
          WearPillButton(
            label: 'Đăng nhập tạm',
            icon: Icons.login_rounded,
            color: WearPalette.faint,
            outlined: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WearLoginScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
