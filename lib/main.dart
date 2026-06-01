import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/money_provider.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MoneyProvider()),
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
