import 'package:flutter/material.dart';

// Thay thế package `wear` — detect round/square screen từ MediaQuery
// Wear OS thường là round (320×320 px, tỷ lệ ~1:1)
// Square watch (Galaxy Watch 4 Classic) có tỷ lệ tương tự nhưng không cần phân biệt nhiều

class WearUtils {
  WearUtils._();

  static bool isRound(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return (size.width / size.height - 1.0).abs() < 0.15;
  }

  static EdgeInsets safePadding(BuildContext context) {
    final round = isRound(context);
    final size  = MediaQuery.of(context).size;
    final inset = round ? size.width * 0.08 : 12.0;
    return EdgeInsets.all(inset);
  }
}
