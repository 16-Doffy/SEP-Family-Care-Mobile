import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/widgets/json_report_view.dart';

/// Nhãn tiếng Việt phải áp dụng ở MỌI nơi dùng `JsonReportView`, không chỉ khi
/// bật `financeReportMode`. Bug thật đã gặp (17/08/2026): màn Trợ lý AI gọi
/// widget này không bật cờ nên hiện "Total Expense", "Active Budget Plan",
/// "Period Start" ngay trên màn người dùng thường dùng.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  const report = {
    'totalExpense': 6120122,
    'balance': 75469878,
    'activeBudgetPlan': {
      'planName': 'Ngân sách tháng 8',
      'lineCount': 1,
      'expectedSharedExpense': 500000,
    },
  };

  testWidgets('không bật financeReportMode vẫn ra nhãn tiếng Việt', (
    tester,
  ) async {
    await pump(tester, const JsonReportView(data: report));

    expect(find.text('Tổng chi'), findsOneWidget);
    expect(find.text('Số dư'), findsOneWidget);
    expect(find.text('Kế hoạch ngân sách đang dùng'), findsOneWidget);
    expect(find.text('Tên kế hoạch'), findsOneWidget);
    expect(find.text('Số danh mục'), findsOneWidget);
    expect(find.text('Chi tiêu dự kiến'), findsOneWidget);

    // Không được còn nhãn tiếng Anh sinh tự động từ tên field.
    expect(find.text('Total Expense'), findsNothing);
    expect(find.text('Balance'), findsNothing);
    expect(find.text('Active Budget Plan'), findsNothing);
  });

  testWidgets('bật financeReportMode cho ra nhãn y hệt', (tester) async {
    await pump(
      tester,
      const JsonReportView(data: report, financeReportMode: true),
    );

    expect(find.text('Tổng chi'), findsOneWidget);
    expect(find.text('Kế hoạch ngân sách đang dùng'), findsOneWidget);
  });

  testWidgets('field lạ chưa có trong bảng thì không làm sập widget', (
    tester,
  ) async {
    await pump(
      tester,
      const JsonReportView(data: {'someBrandNewFieldFromBe': 12}),
    );
    // Rơi về nhãn sinh tự động — chấp nhận được, miễn không crash.
    expect(find.text('Some Brand New Field From Be'), findsOneWidget);
  });
}
