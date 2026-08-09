import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:family_care/providers/finance_provider.dart';
import 'package:family_care/screens/shared/ai_assistant_screen.dart';

/// Quan sát thật 2026-08-09: field `categoryId` (BE tự gán danh mục cho đề
/// xuất ghi khoản chi) hiện nguyên UUID thô trên thẻ AI thay vì tên đọc
/// được. `resolveCategoryName` tra ngược qua `FinanceProvider.categories`
/// (đã tải sẵn ở app scope) để hiện tên thật.
void main() {
  Future<String> resolveIn(
    WidgetTester tester,
    List<FinanceCategory> categories,
    dynamic value,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider()..categories = categories,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return resolveCategoryName(ctx, value);
  }

  const categories = [
    FinanceCategory(
      id: 'cat-1',
      name: 'Ăn uống',
      categoryType: 'EXPENSE',
      status: 'ACTIVE',
      isActive: true,
    ),
  ];

  testWidgets('categoryId khớp danh mục đã tải thì hiện đúng tên', (
    tester,
  ) async {
    final name = await resolveIn(tester, categories, 'cat-1');
    expect(name, 'Ăn uống');
  });

  testWidgets(
    'categoryId không khớp danh mục nào (đã xóa/chưa tải kịp) thì hiện lại '
    'ID thô, không giả vờ có tên',
    (tester) async {
      final name = await resolveIn(tester, categories, 'cat-khong-ton-tai');
      expect(name, 'cat-khong-ton-tai');
    },
  );

  testWidgets('value rỗng/null thì hiện gạch ngang, không crash', (
    tester,
  ) async {
    expect(await resolveIn(tester, categories, null), '-');
    expect(await resolveIn(tester, categories, ''), '-');
  });
}
