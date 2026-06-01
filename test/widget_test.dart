import 'package:family_care_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows redesigned auth screen', (tester) async {
    await tester.pumpWidget(const FamilyCareMobileApp());

    expect(find.text('Family Care'), findsOneWidget);
    expect(find.text('Quan ly gia dinh moi ngay'), findsOneWidget);
    expect(find.text('Dang nhap'), findsWidgets);
  });
}
