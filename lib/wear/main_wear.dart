import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/gps_provider.dart';
import '../providers/sos_provider.dart';
import '../services/api_client.dart';
import 'screens/wear_login_screen.dart';
import 'screens/wear_home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GpsProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
      ],
      child: const WearApp(),
    ),
  );
}

class WearApp extends StatelessWidget {
  const WearApp({super.key});

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
      home: const _WearRoot(),
    );
  }
}

class _WearRoot extends StatelessWidget {
  const _WearRoot();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const WearHomeScreen() : const WearLoginScreen();
  }
}
