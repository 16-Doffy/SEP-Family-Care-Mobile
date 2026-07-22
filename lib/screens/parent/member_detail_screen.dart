import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/avatar_widget.dart';

class MemberDetailScreen extends StatefulWidget {
  final String memberId;

  const MemberDetailScreen({super.key, required this.memberId});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  MonthlySummary? _summary;
  bool _loadingFinance = false;
  String? _financeError;

  FamilyMember? _findMember(List<FamilyMember> members) {
    for (final member in members) {
      if (member.id == widget.memberId || member.userId == widget.memberId) {
        return member;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final family = context.read<FamilyProvider>();
      if (family.members.isEmpty) family.fetchMembers();
      _fetchFinance();
    });
  }

  Future<void> _fetchFinance() async {
    final me = context.read<AuthProvider>().user;
    if (!(me?.canManageFinance ?? false)) return;

    setState(() {
      _loadingFinance = true;
      _financeError = null;
    });

    try {
      final now = DateTime.now();
      final summary = await context
          .read<FinanceProvider>()
          .fetchMemberMonthlySummary(
            widget.memberId,
            month: now.month,
            year: now.year,
          );
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        setState(
          () => _financeError = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFinance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final family = context.watch<FamilyProvider>();
    final member = _findMember(family.members);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hồ sơ thành viên',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if ((me?.canManageFinance ?? false) && member != null)
                    IconButton(
                      tooltip: 'Tài chính tháng',
                      onPressed: () => context.push(
                        '/manager/member-finance?memberId=${member.id}&name=${Uri.encodeQueryComponent(member.name)}',
                      ),
                      icon: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: family.isLoading && member == null
                  ? const Center(child: CircularProgressIndicator())
                  : member == null
                  ? _missingMember()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await family.fetchMembers();
                        await _fetchFinance();
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          _hero(member, me),
                          const SizedBox(height: 16),
                          _infoCard(member),
                          const SizedBox(height: 14),
                          if (me?.canManageFinance ?? false)
                            _financeCard(member),
                          const SizedBox(height: 14),
                          _blockedCard(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(FamilyMember member, AppUser? me) {
    final isMe = member.userId == me?.id;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          AvatarWidget(
            initial: member.avatarInitials,
            color: Color(member.avatarColor),
            size: 84,
          ),
          const SizedBox(height: 14),
          Text(
            member.name + (isMe ? ' (Bạn)' : ''),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(member.roleLabel, member.roleColor),
              if (member.relation.isNotEmpty)
                _chip(member.relation, AppColors.textSecondary),
              _chip(_statusLabel(member.status), _statusColor(member.status)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(FamilyMember member) {
    return _sectionCard(
      title: 'Thông tin',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _row('Email', member.email.isEmpty ? '-' : member.email),
          _row('Vai trò', member.roleLabel),
          _row(
            'Quan hệ',
            member.relation.isEmpty ? 'Chưa có dữ liệu' : member.relation,
          ),
          _row('Trạng thái', _statusLabel(member.status)),
        ],
      ),
    );
  }

  Widget _financeCard(FamilyMember member) {
    if (_loadingFinance) {
      return _sectionCard(
        title: 'Tài chính tháng này',
        icon: Icons.account_balance_wallet_outlined,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_financeError != null) {
      return _sectionCard(
        title: 'Tài chính tháng này',
        icon: Icons.account_balance_wallet_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _financeError!,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _fetchFinance, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final summary = _summary;
    final monthly = summary?.monthlyFinance;
    return _sectionCard(
      title: 'Tài chính tháng này',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        children: [
          if (summary == null || monthly == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Thành viên chưa khai báo tài chính tháng này.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else ...[
            _row(
              'Thu nhập dự kiến',
              _money(monthly.expectedIncome, monthly.incomeVisibility),
            ),
            _row(
              'Chi tiêu dự kiến',
              _money(
                monthly.expectedPersonalExpense,
                monthly.expenseVisibility,
              ),
            ),
            _row(
              'Đóng góp chung dự kiến',
              _money(monthly.expectedSharedContribution, 'FAMILY'),
            ),
            _row('Ghi nhận quỹ gia đình', '${_fmt(summary.fundActual)} ₫'),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(
                '/manager/member-finance?memberId=${member.id}&name=${Uri.encodeQueryComponent(member.name)}',
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Xem tài chính chi tiết'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockedCard() {
    return _sectionCard(
      title: 'Công việc',
      icon: Icons.task_alt_rounded,
      child: Text(
        'Chưa có API lọc công việc theo từng thành viên. Mục này sẽ được bật khi backend bổ sung endpoint phù hợp.',
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _missingMember() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_rounded,
              size: 42,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy thành viên',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Danh sách có thể đã thay đổi. Hãy quay lại và tải lại danh sách thành viên.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _money(double? value, String visibility) {
    if (value == null) return visibility == 'PRIVATE' ? 'Riêng tư' : '-';
    return '${_fmt(value)} ₫';
  }

  String _fmt(double value) {
    final s = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _statusLabel(String status) {
    return switch (status.toUpperCase()) {
      'ACTIVE' => 'Đang hoạt động',
      'REMOVED' => 'Đã rời gia đình',
      'INACTIVE' => 'Tạm ngưng',
      _ => status.isEmpty ? 'Không rõ' : status,
    };
  }

  Color _statusColor(String status) {
    return switch (status.toUpperCase()) {
      'ACTIVE' => AppColors.success,
      'REMOVED' => AppColors.danger,
      'INACTIVE' => AppColors.textMuted,
      _ => AppColors.textSecondary,
    };
  }
}
