import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../wear_utils.dart';

class WearLoginScreen extends StatelessWidget {
  const WearLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = WearUtils.safePadding(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏠', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text('FamilyCare',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 16),
                _roleBtn(context, '👑', 'Ba (Manager)', UserRole.manager, 'Ba Nguyễn'),
                const SizedBox(height: 8),
                _roleBtn(context, '🛡️', 'Mẹ (Deputy)', UserRole.deputy, 'Mẹ Nguyễn'),
                const SizedBox(height: 8),
                _roleBtn(context, '🧒', 'Con (Member)', UserRole.member, 'An Nguyễn'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleBtn(BuildContext ctx, String emoji, String label,
      UserRole role, String name) {
    return GestureDetector(
      onTap: () => ctx.go('/login'),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ]),
      ),
    );
  }
}
