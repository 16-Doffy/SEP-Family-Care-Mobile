import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/services/api_client.dart';

void main() {
  test('ApiException giữ chi tiết lỗi nghiệp vụ để UI hiển thị', () {
    const error = ApiException(
      400,
      'Số tiền chia quỹ vượt quá quỹ khả dụng của kỳ này',
      code: 'INSUFFICIENT_AVAILABLE_FUND',
      details: {
        'requestedAmount': 100000,
        'availableAmount': 25000,
        'periodMonth': 12,
        'periodYear': 2026,
      },
    );

    expect(error.details['requestedAmount'], 100000);
    expect(error.details['availableAmount'], 25000);
    expect(error.details['periodMonth'], 12);
    expect(error.details['periodYear'], 2026);
  });
}
