import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/gps_provider.dart';
import '../providers/sos_provider.dart';
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
      home: const _WearRoot(),
    );
  }
}

class _WearRoot extends StatelessWidget {
  const _WearRoot();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.restoring) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFDC2626),
            ),
          ),
        ),
      );
    }
    return auth.isLoggedIn ? const WearHomeScreen() : const WearLoginScreen();
  }
}
