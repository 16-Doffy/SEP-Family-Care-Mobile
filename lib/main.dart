import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/album_provider.dart';
import 'providers/ai_chatbot_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/tab_config_provider.dart';
import 'providers/wearable_provider.dart';
import 'providers/album_face_provider.dart';
import 'providers/money_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/task_provider.dart';
import 'providers/gps_provider.dart';
import 'providers/sos_provider.dart';
import 'providers/family_provider.dart';
import 'providers/finance_alert_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/invitation_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/support_request_provider.dart';
import 'providers/theme_mode_controller.dart';
import 'theme/app_surface_colors.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AlbumProvider()),
        ChangeNotifierProvider(create: (_) => AiChatbotProvider()),
        ChangeNotifierProvider(create: (_) => MoneyProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => GpsProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => FinanceAlertProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => InvitationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SupportRequestProvider()),
        ChangeNotifierProvider(create: (_) => ThemeModeController()..load()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => TabConfigProvider()),
        ChangeNotifierProvider(create: (_) => WearableProvider()),
        ChangeNotifierProvider(create: (_) => AlbumFaceProvider()),
      ],
      child: const FamilyCareApp(),
    ),
  );
}

class FamilyCareApp extends StatefulWidget {
  const FamilyCareApp({super.key});
  @override
  State<FamilyCareApp> createState() => _FamilyCareAppState();
}

class _FamilyCareAppState extends State<FamilyCareApp> {
  late final _router = createRouter(context.read<AuthProvider>());

  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().tryRestoreSession();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeModeController>().themeMode;
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    final surfaces = isDark ? AppSurfaceColors.dark : AppSurfaceColors.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: surfaces.background,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: surfaces.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    return MaterialApp.router(
      title: 'FamilyCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
