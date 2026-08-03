import 'dart:async';

import 'package:flutter/material.dart';

import 'wear_utils.dart';

class WearPalette {
  WearPalette._();

  static const bg = Colors.black;
  static const surface = Color(0xFF171717);
  static const surface2 = Color(0xFF202020);
  static const line = Color(0xFF2A2A2A);
  static const text = Colors.white;
  static const muted = Colors.white70;
  static const faint = Colors.white38;
  static const sos = Color(0xFFE11D48);
  static const sosSoft = Color(0xFFFDA4AF);
  static const green = Color(0xFF86EFAC);
  static const blue = Color(0xFF7DD3FC);
  static const amber = Color(0xFFFCD34D);
  static const violet = Color(0xFFC4B5FD);
}

bool wearIsLarge(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 225;

class WearPage extends StatefulWidget {
  const WearPage({
    super.key,
    required this.child,
    this.scrollable = false,
    this.padding,
    this.showTime = true,
  });

  final Widget child;
  final bool scrollable;
  final EdgeInsets? padding;
  final bool showTime;

  @override
  State<WearPage> createState() => _WearPageState();
}

class _WearPageState extends State<WearPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = widget.padding ?? WearUtils.contentPadding(context);
    final content = widget.scrollable
        ? RawScrollbar(
            controller: _scrollController,
            thumbColor: Colors.white38,
            radius: const Radius.circular(8),
            thickness: 2,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: resolvedPadding,
              child: widget.child,
            ),
          )
        : Padding(padding: resolvedPadding, child: widget.child);

    return Scaffold(
      backgroundColor: WearPalette.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.showTime) const WearTimeText(),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class WearTimeText extends StatefulWidget {
  const WearTimeText({super.key});

  @override
  State<WearTimeText> createState() => _WearTimeTextState();
}

class _WearTimeTextState extends State<WearTimeText> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '${two(_now.hour)}:${two(_now.minute)}',
        maxLines: 1,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: WearPalette.faint,
        ),
      ),
    );
  }
}

class WearHeader extends StatelessWidget {
  const WearHeader({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.color = WearPalette.muted,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: WearPalette.text,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class WearSectionLabel extends StatelessWidget {
  const WearSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: WearPalette.faint,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class WearTile extends StatelessWidget {
  const WearTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.color = WearPalette.blue,
    this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color.withValues(alpha: 0.16) : WearPalette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled ? color.withValues(alpha: 0.38) : WearPalette.line,
            ),
          ),
          child: Row(
            children: [
              WearRoundIcon(icon: icon, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: WearPalette.text,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: WearPalette.faint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class WearRoundIcon extends StatelessWidget {
  const WearRoundIcon({
    super.key,
    required this.icon,
    this.color = WearPalette.blue,
    this.size = 30,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.54, color: color),
    );
  }
}

class WearEmptyState extends StatelessWidget {
  const WearEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = WearPalette.muted,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: WearPalette.muted,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: WearPalette.faint),
            ),
          ],
        ],
      ),
    );
  }
}

class WearPillButton extends StatelessWidget {
  const WearPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color = WearPalette.sos,
    this.outlined = false,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final bool outlined;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: outlined ? Border.all(color: color, width: 1.2) : null,
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 18,
                        color: outlined ? color : Colors.white,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: outlined ? color : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
