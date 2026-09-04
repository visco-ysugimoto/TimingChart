import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/chart_shortcut_keys.dart';

void main() {
  test('数字キーとテンキーの 0/1 を High/Low に対応付ける', () {
    expect(
      chartLevelValueFromKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.digit1,
          logicalKey: LogicalKeyboardKey.digit1,
          timeStamp: Duration.zero,
        ),
      ),
      1,
    );
    expect(
      chartLevelValueFromKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.numpad0,
          logicalKey: LogicalKeyboardKey.numpad0,
          timeStamp: Duration.zero,
        ),
      ),
      0,
    );
    expect(
      chartLevelValueFromKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        ),
      ),
      isNull,
    );
  });
}
