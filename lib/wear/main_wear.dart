import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/gps_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/sos_provider.dart';
import '../providers/task_provider.dart';
import '../providers/wear_quick_message_provider.dart';
import 'wear_root.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GpsProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
        // Cần cho trang "Việc của tôi" và "Nhắn nhanh" trên đồng hồ.
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        // BẮT BUỘC: WearQuickMessageScreen đọc provider này ngay trong build().
        // Thiếu ở đây thì chạy `flutter run --target lib/wear/main_wear.dart`
        // sẽ nổ ProviderNotFoundException khi mở mục "Nhắn nhanh" — mà chạy
        // entrypoint mặc định lại không lộ, vì main.dart có đăng ký sẵn.
        // Mọi provider mà màn wear đọc phải khai ở CẢ HAI entrypoint.
        ChangeNotifierProvider(create: (_) => WearQuickMessageProvider()),
      ],
      child: const WearApp(),
    ),
  );
}

class WearApp extends StatefulWidget {
  const WearApp({super.key});

  @override
  State<WearApp> createState() => _WearAppState();
}

class _WearAppState extends State<WearApp> {
  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().tryRestoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyCare Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFDC2626),
          surface: Color(0xFF1A1A1A),
        ),
      ),
      home: const WearRoot(),
    );
  }
}
