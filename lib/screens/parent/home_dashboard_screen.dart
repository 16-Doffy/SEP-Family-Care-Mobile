import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    final transactions = [
      _TxData(emoji: '🏆', title: 'Thưởng task · An', sub: 'Dọn phòng · 09:41', amount: '+20,000 ₫', positive: true),
      _TxData(emoji: '🛒', title: 'Siêu thị gia đình', sub: 'Chi chung · 08:10', amount: '-420,000 ₫', positive: false),
      _TxData(emoji: '🍦', title: 'Ăn tối gia đình', sub: 'Chi chung · 19:30', amount: '-280,000 ₫', positive: false),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(right: -60, bottom: 120, child: Container(width: 220, height: 220, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accentGlow))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 8),

                // Header
                Row(
                  children: [
                    AvatarWidget(initial: user?.avatarInitials ?? 'BA', color: AppColors.avatarBlue, size: 44, showPresence: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Xin chào, ${user?.name ?? "Ba"} 👋', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('Gia đình ${user?.familyName ?? "Nguyễn"} · Thứ Tư', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Stack(
                        children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(21), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
                            child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textPrimary)),
                          Positioned(top: 8, right: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.notification))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Hero wallet card
                GestureDetector(
                  onTap: () => context.push('/manager/wallet'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.heroOrange, AppColors.heroPurple], begin: Alignment.centerLeft, end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 44, offset: const Offset(0, 18))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quỹ Gia Đình', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('12,500,000 ₫', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Text('↑ +3.2M vs tháng trước', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFDCFCE7))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick actions
                Row(
                  children: [
                    _quickCard('➕', 'Nạp', () => context.push('/manager/wallet')),
                    const SizedBox(width: 12),
                    _quickCard('↗', 'Chuyển', () => context.push('/manager/wallet')),
                    const SizedBox(width: 12),
                    _quickCard('📋', 'Tasks', () => context.push('/manager/tasks')),
                    const SizedBox(width: 12),
                    _quickCard('📅', 'Lịch', () => context.go('/manager/calendar')),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/manager/tasks'),
                        child: _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [const Icon(Icons.assignment_outlined, size: 16, color: AppColors.textPrimary), const SizedBox(width: 8), Text('Tasks', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]),
                              const SizedBox(height: 4),
                              Text('3 / 5 hoàn thành', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: 0.6, minHeight: 8,
                                        backgroundColor: AppColors.progressTrack,
                                        valueColor: const AlwaysStoppedAnimation(AppColors.success),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('60%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [const Icon(Icons.people_outline, size: 16, color: AppColors.textPrimary), const SizedBox(width: 8), Text('3 online', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]),
                            const SizedBox(height: 4),
                            Text('Đang ở nhà', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                AvatarWidget(initial: 'M', color: AppColors.avatarPurple, size: 28, showPresence: true),
                                Transform.translate(offset: const Offset(-10, 0), child: AvatarWidget(initial: 'A', color: AppColors.avatarOrange, size: 28, showPresence: true)),
                                Transform.translate(offset: const Offset(-20, 0), child: AvatarWidget(initial: 'B', color: AppColors.avatarBlue, size: 28, showPresence: true)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // AI teaser
                GestureDetector(
                  onTap: () => context.push('/ai'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trợ lý AI', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              Text('Hỏi về chi tiêu, tasks hay mẹo tiết kiệm…', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        const Text('→', style: TextStyle(fontSize: 18, color: AppColors.link)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Transactions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Giao dịch gần đây', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    GestureDetector(onTap: () => context.push('/manager/wallet'), child: Text('Xem tất cả →', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.link))),
                  ],
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    children: transactions.map((tx) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(width: 38, height: 38, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3F4F6)), alignment: Alignment.center, child: Text(tx.emoji, style: const TextStyle(fontSize: 18))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tx.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(tx.sub, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          ])),
                          Text(tx.amount, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: tx.positive ? AppColors.success : AppColors.danger)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCard(String icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _TxData {
  final String emoji, title, sub, amount;
  final bool positive;
  const _TxData({required this.emoji, required this.title, required this.sub, required this.amount, required this.positive});
}
