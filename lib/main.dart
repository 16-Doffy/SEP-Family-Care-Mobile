import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/money_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/task_provider.dart';
import 'providers/gps_provider.dart';
import 'providers/sos_provider.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // WalletProvider và MoneyProvider nhận familyId từ AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
          create: (_) => WalletProvider(),
          update: (_, auth, wallet) {
            final fid = auth.familyId;
            if (fid != null) wallet!.familyId = fid;
            return wallet!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, MoneyProvider>(
          create: (_) => MoneyProvider(),
          update: (_, auth, money) {
            final fid = auth.familyId;
            if (fid != null) money!.familyId = fid;
            return money!;
          },
        ),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => GpsProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
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
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FamilyCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
