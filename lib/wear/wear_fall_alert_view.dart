import 'package:flutter/material.dart';

import 'wear_widgets.dart';

class WearFallAlertView extends StatelessWidget {
  const WearFallAlertView({
    super.key,
    required this.icon,
    required this.title,
    required this.reading,
    required this.question,
    required this.countdown,
    required this.dismissLabel,
    required this.onDismiss,
    required this.onSendNow,
    this.scrollController,
  });

  final IconData icon;
  final String title;
  final String reading;
  final String question;
  final int countdown;
  final String dismissLabel;
  final VoidCallback onDismiss;
  final VoidCallback onSendNow;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final buttonHeight = shortestSide <= 240 ? 40.0 : 48.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: WearPalette.sos),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: WearPalette.text,
                  ),
                ),
                if (reading.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reading,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: WearPalette.sos,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '$question · tự gửi sau $countdown giây',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 8, color: WearPalette.faint),
                ),
                const SizedBox(height: 6),
                WearPillButton(
                  label: dismissLabel,
                  icon: Icons.check_rounded,
                  color: WearPalette.green,
                  height: buttonHeight,
                  onTap: onDismiss,
                ),
                const SizedBox(height: 4),
                WearPillButton(
                  label: 'Gửi SOS',
                  icon: Icons.sos_rounded,
                  color: WearPalette.sos,
                  height: buttonHeight,
                  onTap: onSendNow,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
