import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';

void main() {
  test('SignalData.toggleVisibilityが表示状態を反転する', () {
    const original = SignalData(
      name: 'test',
      signalType: SignalType.input,
      values: [0, 1],
      isVisible: true,
    );

    final toggled = original.toggleVisibility();

    expect(toggled.isVisible, isFalse);
    // 元のオブジェクトは不変であることも確認
    expect(original.isVisible, isTrue);
  });

  test('copyWith は colorArgb を更新・クリアできる', () {
    const original = SignalData(
      name: 'NOTE',
      signalType: SignalType.auxiliary,
      values: [0, 1],
      showIoNumber: false,
      colorArgb: 0xFFFF9800,
    );

    final updated = original.copyWith(colorArgb: 0xFF2196F3);
    expect(updated.colorArgb, 0xFF2196F3);
    expect(original.colorArgb, 0xFFFF9800);

    final cleared = original.copyWith(clearColorArgb: true);
    expect(cleared.colorArgb, isNull);
  });
}
