import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/family_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/money_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/task_provider.dart';
import 'providers/gps_provider.dart';
import 'providers/sos_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/subscription_provider.dart';
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
            final canManageFinance = auth.user?.canManageSharedFinance ?? false;
            if (fid != null && canManageFinance) {
              wallet!.familyId = fid;
            } else {
              wallet!.clear();
            }
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
        ChangeNotifierProxyProvider<AuthProvider, FamilyProvider>(
          create: (_) => FamilyProvider(),
          update: (_, auth, family) {
            final fid = auth.familyId;
            if (fid != null) family!.familyId = fid;
            return family!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, FinanceProvider>(
          create: (_) => FinanceProvider(),
          update: (_, auth, finance) {
            final fid = auth.familyId;
            if (fid != null) finance!.familyId = fid;
            return finance!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, TaskProvider>(
          create: (_) => TaskProvider(),
          update: (_, auth, task) {
            final fid = auth.familyId;
            if (fid != null) task!.familyId = fid;
            return task!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, GpsProvider>(
          create: (_) => GpsProvider(),
          update: (_, auth, gps) {
            final fid = auth.familyId;
            if (fid != null) gps!.familyId = fid;
            return gps!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, SosProvider>(
          create: (_) => SosProvider(),
          update: (_, auth, sos) {
            final fid = auth.familyId;
            if (fid != null) sos!.familyId = fid;
            return sos!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notif) {
            final fid = auth.familyId;
            if (fid != null) notif!.familyId = fid;
            return notif!;
          },
        ),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
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
