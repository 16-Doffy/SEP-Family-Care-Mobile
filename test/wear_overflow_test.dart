import 'package:family_care/wear/wear_fall_alert_view.dart';
import 'package:family_care/wear/wear_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> expectNoOverflow(
  WidgetTester tester,
  Widget child, {
  required Size physicalSize,
  double devicePixelRatio = 2.0,
  required double textScale,
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
  final logicalSize = physicalSize / devicePixelRatio;

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: logicalSize,
          devicePixelRatio: devicePixelRatio,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );

  expect(
    tester.takeException(),
    isNull,
    reason:
        'tràn ở physical ${physicalSize.width}x${physicalSize.height}, '
        'logical ${logicalSize.width}x${logicalSize.height}, '
        'textScale $textScale',
  );
}

void main() {
  group('WearFallAlertView không tràn layout', () {
    const physicalSizes = [Size(384, 384), Size(454, 454), Size(360, 360)];
    const textScales = [1.0, 1.15, 1.3];
    const countdowns = [20, 14, 1];
    const cases = [
      (
        icon: Icons.accessibility_new_rounded,
        title: 'Phát hiện té ngã',
        reading: '',
        question: 'Bạn có ổn không?',
        dismissLabel: 'Con ổn',
      ),
      (
        icon: Icons.monitor_heart_rounded,
        title: 'Nhịp tim bất thường',
        reading: '142 bpm',
        question: 'Bạn có cần trợ giúp không?',
        dismissLabel: 'Đã ổn',
      ),
      (
        icon: Icons.heart_broken_rounded,
        title: 'Nhịp tim bất thường',
        reading: '38 bpm',
        question: 'Bạn có cần trợ giúp không?',
        dismissLabel: 'Đã ổn',
      ),
    ];

    for (final physicalSize in physicalSizes) {
      for (final textScale in textScales) {
        for (final countdown in countdowns) {
          for (final c in cases) {
            testWidgets(
              '${c.title} ${c.reading} ${physicalSize.width}x${physicalSize.height} textScale $textScale countdown $countdown',
              (tester) async {
                await expectNoOverflow(
                  tester,
                  WearPage(
                    child: WearFallAlertView(
                      icon: c.icon,
                      title: c.title,
                      reading: c.reading,
                      question: c.question,
                      countdown: countdown,
                      dismissLabel: c.dismissLabel,
                      onDismiss: () {},
                      onSendNow: () {},
                    ),
                  ),
                  physicalSize: physicalSize,
                  textScale: textScale,
                );
              },
            );
          }
        }
      }
    }

    for (final c in cases) {
      testWidgets(
        '${c.title} ${c.reading} 454x454 textScale 1.0 không cần cuộn',
        (tester) async {
          final controller = ScrollController();
          addTearDown(controller.dispose);

          await expectNoOverflow(
            tester,
            WearPage(
              child: WearFallAlertView(
                icon: c.icon,
                title: c.title,
                reading: c.reading,
                question: c.question,
                countdown: 14,
                dismissLabel: c.dismissLabel,
                onDismiss: () {},
                onSendNow: () {},
                scrollController: controller,
              ),
            ),
            physicalSize: const Size(454, 454),
            textScale: 1.0,
          );

          expect(
            controller.position.maxScrollExtent,
            0,
            reason: '454px mặc định phải thấy sẵn cả hai nút, không cần cuộn',
          );
        },
      );
    }
  });
}
