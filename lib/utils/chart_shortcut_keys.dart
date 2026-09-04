import 'package:flutter/services.dart';

/// 選択範囲を High(1) / Low(0) にするキー入力ならその値を返す。
int? chartLevelValueFromKeyEvent(KeyEvent event) {
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.digit1 ||
      key == LogicalKeyboardKey.numpad1 ||
      event.character == '1') {
    return 1;
  }
  if (key == LogicalKeyboardKey.digit0 ||
      key == LogicalKeyboardKey.numpad0 ||
      event.character == '0') {
    return 0;
  }
  return null;
}
