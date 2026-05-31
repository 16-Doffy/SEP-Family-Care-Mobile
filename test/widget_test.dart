import 'package:family_care_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows auth screen', (tester) async {
    await tester.pumpWidget(const FamilyCareMobileApp());

    expect(find.text('Family Care'), findsOneWidget);
    expect(find.text('Dang nhap'), findsOneWidget);
  });
}
