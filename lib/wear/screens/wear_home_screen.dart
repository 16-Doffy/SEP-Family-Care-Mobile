import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/gps_provider.dart';
import '../../providers/sos_provider.dart';
import 'wear_map_screen.dart';
import 'wear_quick_message_screen.dart';
import 'wear_sos_screen.dart';
import 'wear_tasks_screen.dart';

class WearHomeScreen extends StatefulWidget {
  const WearHomeScreen({super.key});
  @override
  State<WearHomeScreen> createState() => _WearHomeScreenState();
}

class _WearHomeScreenState extends State<WearHomeScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SosProvider>().fetchAlerts();
      context.read<GpsProvider>().fetchFamilyLocations();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = context.watch<SosProvider>().activeAlerts;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            // 4 việc đồng hồ cần làm, vuốt ngang. Không bê bottom-nav hay
            // dashboard của app điện thoại sang đây.
            children: const [
              WearSosScreen(),
              WearMapScreen(),
              WearTasksScreen(),
              WearQuickMessageScreen(),
            ],
          ),

          // Dot indicators
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final isActive = _page == i;
                // Có cảnh báo đang diễn ra thì chấm SOS (trang 0) đỏ lên.
                final hasAlert = i == 0 && activeAlerts.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 7 : 4,
                  height: isActive ? 7 : 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasAlert
                        ? const Color(0xFFDC2626)
                        : isActive
                        ? Colors.white
                        : Colors.white30,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
